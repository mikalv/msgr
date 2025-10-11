defmodule MessngrWeb.ConversationChannel do
  @moduledoc """
  Phoenix Channel som eksponerer sanntidsoppdateringer for samtaler.
  """

  use MessngrWeb, :channel

  alias Ecto.Changeset
  alias Messngr
  alias Messngr.Accounts.Profile
  alias Messngr.Chat
  alias MessngrWeb.MessageJSON
  alias MessngrWeb.Presence

  @typing_timeout_ms 5_000
  @watcher_timeout_ms 30_000

  @impl true
  def join("conversation:" <> conversation_id, params, socket) do
    with {:ok, profile} <- fetch_profile(params),
         :ok <- authorize_membership(conversation_id, profile) do
      :ok = Chat.subscribe_to_conversation(conversation_id)

      socket =
        socket
        |> assign(:conversation_id, conversation_id)
        |> assign(:current_profile, profile)
        |> assign(:typing_timers, %{})
        |> assign(:watcher_timer, nil)
        |> assign(:last_activity_at, System.monotonic_time(:millisecond))

      send(self(), :after_join)

      socket = reschedule_watcher(socket)

      {:ok, socket}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_in("message:create", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, body} <- extract_body(payload),
         {:ok, message} <-
           Messngr.send_message(socket.assigns.conversation_id, socket.assigns.current_profile.id, %{
             "body" => body
           }) do
      {:reply, {:ok, MessageJSON.show(%{message: message})}, socket}
    else
      {:error, %Changeset{} = changeset} -> reply_changeset_error(socket, changeset)
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("message:create", _payload, socket) do
    {:reply, {:error, %{errors: ["invalid payload"]}}, socket}
  end

  def handle_in("message:update", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         attrs <- Map.take(payload, ["body", "payload", "metadata"]),
         {:ok, message} <-
           Messngr.update_message(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id,
             attrs
           ) do
      {:reply, {:ok, MessageJSON.show(%{message: message})}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("message:delete", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         opts <- Map.take(payload, ["metadata"]),
         {:ok, message} <-
           Messngr.delete_message(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id,
             opts
           ) do
      {:reply, {:ok, MessageJSON.show(%{message: message})}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("message:read", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         {:ok, _participant} <-
           Messngr.mark_message_read(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id
           ) do
      {:reply, {:ok, %{status: "read"}}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("reaction:add", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         {:ok, emoji} <- require_emoji(payload),
         {:ok, metadata} <- fetch_metadata(payload),
         {:ok, reaction} <-
           Messngr.react_to_message(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id,
             emoji,
             %{"metadata" => metadata}
           ) do
      {:reply, {:ok, %{reaction: format_reaction_struct(reaction)}}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("reaction:remove", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         {:ok, emoji} <- require_emoji(payload),
         {:ok, result} <-
           Messngr.remove_reaction(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id,
             emoji
           ) do
      {:reply, {:ok, %{status: to_string(result)}}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("message:pin", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         {:ok, metadata} <- fetch_metadata(payload),
         {:ok, pinned} <-
           Messngr.pin_message(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id,
             %{"metadata" => metadata}
           ) do
      {:reply, {:ok, %{pinned: format_pinned_struct(pinned)}}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("message:unpin", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    with {:ok, message_id} <- require_message_id(payload),
         {:ok, status} <-
           Messngr.unpin_message(
             socket.assigns.conversation_id,
             socket.assigns.current_profile.id,
             message_id
           ) do
      {:reply, {:ok, %{status: to_string(status)}}, socket}
    else
      {:error, reason} -> reply_reason_error(socket, reason)
    end
  end

  def handle_in("typing:start", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    thread_id = Map.get(payload, "thread_id") || Map.get(payload, :thread_id)
    key = typing_key(thread_id)
    socket = put_typing_timer(socket, key)
    update_presence_typing(socket, key, true)

    broadcast_typing(socket, "typing_started", typing_payload(socket, thread_id, include_expiry: true))

    {:noreply, socket}
  end

  def handle_in("typing:stop", payload, socket) when is_map(payload) do
    socket = touch_activity(socket)

    thread_id = Map.get(payload, "thread_id") || Map.get(payload, :thread_id)
    key = typing_key(thread_id)
    {socket, removed?} = remove_typing_timer(socket, key)
    update_presence_typing(socket, key, false)

    if removed? do
      broadcast_typing(socket, "typing_stopped", typing_payload(socket, thread_id))
    end

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{errors: ["unknown event"]}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    meta =
      presence_meta(socket, %{
        typing: %{},
        joined_at: DateTime.utc_now(),
        last_active_at: DateTime.utc_now()
      })

    {:ok, _} = Presence.track(socket, socket.assigns.current_profile.id, meta)
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing_timeout, key}, socket) do
    {socket, removed?} = remove_typing_timer(socket, key)

    if removed? do
      update_presence_typing(socket, key, false)
      broadcast_typing(socket, "typing_stopped", typing_payload(socket, thread_id_from_key(key)))
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:watcher_timeout, socket) do
    now = System.monotonic_time(:millisecond)
    last = socket.assigns.last_activity_at || 0

    if now - last >= @watcher_timeout_ms do
      update_presence(socket, fn metadata ->
        metadata
        |> Map.put(:status, :inactive)
        |> Map.put(:inactive_since, DateTime.utc_now())
      end)

      {:noreply, assign(socket, :watcher_timer, nil)}
    else
      {:noreply, reschedule_watcher(socket)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    push(socket, "message_created", MessageJSON.show(%{message: message}))
    {:noreply, socket}
  end

  def handle_info({:message_updated, message}, socket) do
    push(socket, "message_updated", MessageJSON.show(%{message: message}))
    {:noreply, socket}
  end

  def handle_info({:message_deleted, payload}, socket) do
    push(socket, "message_deleted", format_message_deleted(payload))
    {:noreply, socket}
  end

  def handle_info({:reaction_added, payload}, socket) do
    push(socket, "reaction_added", format_reaction_event(payload))
    {:noreply, socket}
  end

  def handle_info({:reaction_removed, payload}, socket) do
    push(socket, "reaction_removed", format_reaction_event(payload))
    {:noreply, socket}
  end

  def handle_info({:message_pinned, payload}, socket) do
    push(socket, "message_pinned", format_pinned_event(payload))
    {:noreply, socket}
  end

  def handle_info({:message_unpinned, payload}, socket) do
    push(socket, "message_unpinned", format_pinned_event(payload))
    {:noreply, socket}
  end

  def handle_info({:message_read, payload}, socket) do
    push(socket, "message_read", format_message_read(payload))
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp fetch_profile(%{"account_id" => account_id, "profile_id" => profile_id}) do
    profile = Chat.ensure_profile!(account_id, profile_id)
    {:ok, profile}
  rescue
    _ -> {:error, %{reason: "unauthorized"}}
  end

  defp fetch_profile(_), do: {:error, %{reason: "unauthorized"}}

  defp authorize_membership(conversation_id, profile) do
    case Messngr.ensure_membership(conversation_id, profile.id) do
      _participant -> :ok
    end
  rescue
    Ecto.NoResultsError -> {:error, %{reason: "forbidden"}}
  end

  defp extract_body(%{"body" => body}) when is_binary(body) do
    trimmed = String.trim(body)

    if trimmed == "" do
      {:error, %{errors: ["body can't be blank"]}}
    else
      {:ok, trimmed}
    end
  end

  defp extract_body(_), do: {:error, %{errors: ["body is required"]}}

  defp require_message_id(payload) do
    case Map.get(payload, "message_id") || Map.get(payload, :message_id) do
      id when is_binary(id) and byte_size(id) > 0 -> {:ok, id}
      _ -> {:error, "message_id is required"}
    end
  end

  defp require_emoji(payload) do
    case Map.get(payload, "emoji") || Map.get(payload, :emoji) do
      emoji when is_binary(emoji) and byte_size(String.trim(emoji)) > 0 -> {:ok, emoji}
      _ -> {:error, "emoji is required"}
    end
  end

  defp fetch_metadata(payload) do
    case Map.get(payload, "metadata") || Map.get(payload, :metadata) do
      nil -> {:ok, %{}}
      %{} = metadata -> {:ok, metadata}
      _ -> {:error, "metadata must be an object"}
    end
  end

  defp reply_changeset_error(socket, changeset) do
    {:reply, {:error, %{errors: translate_errors(changeset)}}, socket}
  end

  defp reply_reason_error(socket, %Changeset{} = changeset), do: reply_changeset_error(socket, changeset)

  defp reply_reason_error(socket, %{reason: reason}) when is_binary(reason) do
    {:reply, {:error, %{errors: [reason]}}, socket}
  end

  defp reply_reason_error(socket, reason) when is_atom(reason) do
    {:reply, {:error, %{errors: [translate_reason(reason)]}}, socket}
  end

  defp reply_reason_error(socket, reason) when is_binary(reason) do
    {:reply, {:error, %{errors: [reason]}}, socket}
  end

  defp reply_reason_error(socket, {:error, reason}), do: reply_reason_error(socket, reason)

  defp reply_reason_error(socket, reason) do
    {:reply, {:error, %{errors: [inspect(reason)]}}, socket}
  end

  defp translate_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp translate_reason(:forbidden), do: "forbidden"
  defp translate_reason(:invalid_emoji), do: "invalid emoji"
  defp translate_reason(:invalid_metadata), do: "invalid metadata"
  defp translate_reason(:message_not_found), do: "message not found"
  defp translate_reason(:message_deleted), do: "message deleted"
  defp translate_reason(:invalid_payload), do: "invalid payload"
  defp translate_reason(other), do: to_string(other)

  defp touch_activity(socket) do
    update_presence(socket, fn metadata ->
      metadata
      |> Map.put(:status, :active)
      |> Map.put(:last_active_at, DateTime.utc_now())
      |> Map.delete(:inactive_since)
    end)

    socket
    |> assign(:last_activity_at, System.monotonic_time(:millisecond))
    |> reschedule_watcher()
  end

  defp reschedule_watcher(socket) do
    if ref = socket.assigns[:watcher_timer] do
      Process.cancel_timer(ref, async: true, info: false)
    end

    ref = Process.send_after(self(), :watcher_timeout, @watcher_timeout_ms)
    assign(socket, :watcher_timer, ref)
  end

  defp typing_key(nil), do: "root"
  defp typing_key(thread_id), do: thread_id

  defp thread_id_from_key("root"), do: nil
  defp thread_id_from_key(key), do: key

  defp put_typing_timer(socket, key) do
    {socket, _} = remove_typing_timer(socket, key)
    ref = Process.send_after(self(), {:typing_timeout, key}, @typing_timeout_ms)
    timers = Map.put(socket.assigns.typing_timers, key, ref)
    assign(socket, :typing_timers, timers)
  end

  defp remove_typing_timer(socket, key) do
    {ref, timers} = Map.pop(socket.assigns.typing_timers, key)

    if ref do
      Process.cancel_timer(ref, async: true, info: false)
      {assign(socket, :typing_timers, timers), true}
    else
      {socket, false}
    end
  end

  defp broadcast_typing(socket, event, payload) do
    broadcast_from!(socket, event, payload)
  end

  defp typing_payload(socket, thread_id, opts \\ []) do
    payload = %{
      profile_id: socket.assigns.current_profile.id,
      profile_name: socket.assigns.current_profile.name,
      thread_id: thread_id
    }

    if Keyword.get(opts, :include_expiry, false) do
      expires_at = DateTime.add(DateTime.utc_now(), @typing_timeout_ms, :millisecond)
      Map.put(payload, :expires_at, encode_datetime(expires_at))
    else
      payload
    end
  end

  defp update_presence_typing(socket, key, active?) do
    update_presence(socket, fn metadata ->
      typing = Map.get(metadata, :typing, %{})

      updated_typing =
        if active? do
          Map.put(typing, key, DateTime.utc_now())
        else
          Map.delete(typing, key)
        end

      Map.put(metadata, :typing, updated_typing)
    end)
  end

  defp update_presence(socket, fun) when is_function(fun, 1) do
    case Presence.update(socket, socket.assigns.current_profile.id, fn metadata ->
           metadata
           |> Map.put_new(:typing, %{})
           |> fun.()
         end) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp presence_meta(socket, overrides \\ %{}) do
    base = %{
      profile_id: socket.assigns.current_profile.id,
      profile_name: socket.assigns.current_profile.name,
      status: :active
    }

    Map.merge(base, overrides)
  end

  defp format_reaction_struct(reaction) do
    %{
      id: reaction.id,
      message_id: reaction.message_id,
      profile_id: reaction.profile_id,
      emoji: reaction.emoji,
      metadata: reaction.metadata || %{},
      inserted_at: encode_datetime(reaction.inserted_at),
      updated_at: encode_datetime(reaction.updated_at),
      profile: format_profile(reaction.profile)
    }
  end

  defp format_reaction_event(payload) do
    payload
    |> Map.update(:inserted_at, nil, &encode_datetime/1)
    |> Map.update(:updated_at, nil, &encode_datetime/1)
    |> Map.update(:aggregates, [], fn aggregates ->
      Enum.map(aggregates, &format_reaction_aggregate/1)
    end)
  end

  defp format_reaction_aggregate(aggregate) do
    aggregate
    |> Map.update(:emoji, "", & &1)
    |> Map.update(:count, 0, & &1)
    |> Map.update(:profile_ids, [], & &1)
  end

  defp format_pinned_struct(pinned) do
    %{
      id: pinned.id,
      conversation_id: pinned.conversation_id,
      message_id: pinned.message_id,
      pinned_by_id: pinned.pinned_by_id,
      pinned_at: encode_datetime(pinned.pinned_at),
      metadata: pinned.metadata || %{},
      pinned_by: format_profile(pinned.pinned_by)
    }
  end

  defp format_pinned_event(payload) do
    payload
    |> Map.update(:pinned_at, nil, &encode_datetime/1)
  end

  defp format_message_read(payload) do
    payload
    |> Map.update(:read_at, nil, &encode_datetime/1)
  end

  defp format_message_deleted(%{message_id: message_id} = payload) do
    %{
      message_id: message_id,
      deleted_at: encode_datetime(Map.get(payload, :deleted_at))
    }
  end

  defp format_message_deleted(payload) when is_map(payload) do
    payload
    |> Map.new(fn {key, value} ->
      case key do
        :deleted_at -> {key, encode_datetime(value)}
        _ -> {key, value}
      end
    end)
  end

  defp format_profile(%Profile{} = profile) do
    %{
      id: profile.id,
      name: profile.name,
      mode: profile.mode
    }
  end

  defp format_profile(_), do: nil

  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp encode_datetime(value), do: value
end
