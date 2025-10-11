defmodule MessngrWeb.ConversationChannel do
  @moduledoc """
  Phoenix Channel som eksponerer sanntidsoppdateringer for samtaler.
  """

  use MessngrWeb, :channel

  alias Ecto.Changeset
  alias Messngr
  alias Messngr.Chat
  alias MessngrWeb.{ConversationPresence, MessageJSON}

  @impl true
  def join("conversation:" <> conversation_id, params, socket) do
    with {:ok, profile} <- fetch_profile(params),
         :ok <- authorize_membership(conversation_id, profile) do
      :ok = Chat.subscribe_to_conversation(conversation_id)

      socket =
        socket
        |> assign(:conversation_id, conversation_id)
        |> assign(:current_profile, profile)

      {:ok, socket}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_in("message:create", payload, socket) when is_map(payload) do
    with {:ok, body} <- extract_body(payload),
         {:ok, message} <-
           Messngr.send_message(socket.assigns.conversation_id, socket.assigns.current_profile.id, %{
             "body" => body
           }) do
      {:reply, {:ok, MessageJSON.show(%{message: message})}, socket}
    else
      {:error, %Changeset{} = changeset} ->
        {:reply, {:error, %{errors: translate_errors(changeset)}}, socket}

      {:error, %{errors: _} = errors} ->
        {:reply, {:error, errors}, socket}

      {:error, %{reason: _} = reason} ->
        {:reply, {:error, reason}, socket}

      {:error, reason} when is_binary(reason) ->
        {:reply, {:error, %{errors: [reason]}}, socket}
    end
  end

  def handle_in("message:create", _payload, socket) do
    {:reply, {:error, %{errors: ["invalid payload"]}}, socket}
  end

  def handle_in("message:sync", params, socket) when is_map(params) do
    opts = build_list_opts(params)
    page = Messngr.list_messages(socket.assigns.conversation_id, opts)

    :ok = Chat.broadcast_backlog(socket.assigns.conversation_id, page)

    {:reply, :ok, socket}
  end

  def handle_in("message:sync", _params, socket) do
    {:reply, {:error, %{errors: ["invalid payload"]}}, socket}
  end

  def handle_in("conversation:watch", _params, socket) do
    profile = socket.assigns.current_profile

    {:ok, _} =
      ConversationPresence.track(socket, profile.id, %{
        profile_id: profile.id,
        name: profile.name,
        mode: profile.mode
      })

    {:reply, {:ok, %{watchers: ConversationPresence.list(socket)}}, socket}
  end

  def handle_in("conversation:unwatch", _params, socket) do
    :ok = ConversationPresence.untrack(socket, socket.assigns.current_profile.id)
    {:reply, :ok, socket}
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    push(socket, "message_created", MessageJSON.show(%{message: message}))
    {:noreply, socket}
  end

  def handle_info({:message_page, page}, socket) do
    push(socket, "message_page", MessageJSON.index(%{page: page}))
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

  defp translate_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp build_list_opts(params) do
    []
    |> maybe_put(:limit, params["limit"])
    |> maybe_put(:before_id, params["before_id"])
    |> maybe_put(:after_id, params["after_id"])
    |> maybe_put(:around_id, params["around_id"])
  end

  defp maybe_put(opts, _key, nil), do: opts

  defp maybe_put(opts, :limit, value) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 and int <= 200 -> Keyword.put(opts, :limit, int)
      _ -> opts
    end
  end

  defp maybe_put(opts, key, value) when key in [:before_id, :after_id, :around_id] do
    Keyword.put(opts, key, value)
  end
end
