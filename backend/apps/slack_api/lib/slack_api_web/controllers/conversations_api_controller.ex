defmodule SlackApiWeb.Controllers.ConversationsApiController do
  use SlackApiWeb, :controller

  require Logger

  import Ecto.Query

  alias Messngr
  alias Messngr.Chat.{Conversation, Message, Participant}
  alias Messngr.Repo
  alias SlackApi.{SlackAdapter, SlackId, SlackResponse, SlackTimestamp}

  def init(opts \\ []) do
    Logger.info("Started ConversationsApiController with options #{inspect(opts)}")
  end

  def create(conn, _params), do: render_not_implemented(conn)
  def mark(conn, params) do
    current_profile = conn.assigns.current_profile

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, ts} <- fetch_required(params, "ts"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, message_id} <- decode_message_ts(ts),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, _participant} <-
           Messngr.mark_message_read(conversation_id, current_profile.id, message_id) do
      json(
        conn,
        SlackResponse.success(%{
          channel: SlackId.conversation({kind, conversation_id}),
          ts: ts
        })
      )
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_ts} ->
        json(conn, SlackResponse.error(:missing_ts))

      {:error, :invalid_ts} ->
        json(conn, SlackResponse.error(:invalid_ts))

      :error ->
        json(conn, SlackResponse.error(:invalid_channel))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end
  def replies(conn, _params), do: render_not_implemented(conn)
  def setPurpose(conn, _params), do: render_not_implemented(conn)
  def setTopic(conn, _params), do: render_not_implemented(conn)

  def history(conn, params) do
    current_profile = conn.assigns.current_profile
    current_account = conn.assigns.current_account

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, _membership} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, paging_opts} <- message_paging_opts(params),
         page <- Messngr.list_messages(conversation_id, paging_opts) do
      conversation_stub = %Conversation{id: conversation_id, kind: kind}

      messages =
        Enum.map(page.entries, fn message ->
          SlackAdapter.message(message,
            account: current_account,
            conversation: conversation_stub
          )
        end)

      next_cursor =
        if page.meta[:has_more][:before] do
          SlackId.message_cursor(page.meta[:start_cursor]) || ""
        else
          ""
        end

      response =
        SlackResponse.success(%{
          messages: messages,
          has_more: page.meta[:has_more][:before],
          response_metadata: %{next_cursor: next_cursor}
        })

      json(conn, response)
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      :error ->
        json(conn, SlackResponse.error(:invalid_channel))

      {:error, :invalid_cursor} ->
        json(conn, SlackResponse.error(:invalid_cursor))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))
    end
  end

  def info(conn, params) do
    current_profile = conn.assigns.current_profile
    current_account = conn.assigns.current_account

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, {_kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, conversation} <- load_conversation(conversation_id, current_profile.id) do
      payload = SlackAdapter.conversation(conversation, account: current_account)

      json(conn, SlackResponse.success(%{channel: payload}))
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :not_found} ->
        json(conn, SlackResponse.error(:channel_not_found))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      :error ->
        json(conn, SlackResponse.error(:invalid_channel))
    end
  end

  def list(conn, params) do
    current_profile = conn.assigns.current_profile
    current_account = conn.assigns.current_account

    with {:ok, after_id} <- decode_cursor(Map.get(params, "cursor")) do
      page = Messngr.list_conversations(current_profile.id, list_options(params, after_id))

      channels =
        Enum.map(page.entries, fn conversation ->
          SlackAdapter.conversation(conversation, account: current_account)
        end)

      next_cursor =
        if page.meta[:has_more][:after] do
          SlackId.cursor(page.meta[:end_cursor]) || ""
        else
          ""
        end

      response =
        SlackResponse.success(%{
          channels: channels,
          response_metadata: %{next_cursor: next_cursor}
        })

      json(conn, response)
    else
      {:error, :invalid_cursor} ->
        json(conn, SlackResponse.error(:invalid_cursor))
    end
  end

  def members(conn, params) do
    current_profile = conn.assigns.current_profile

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, {_kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, conversation} <- load_conversation(conversation_id, current_profile.id) do
      members =
        conversation.participants
        |> Enum.map(&SlackId.profile(&1.profile_id))

      json(conn, SlackResponse.success(%{members: members, count: length(members)}))
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :not_found} ->
        json(conn, SlackResponse.error(:channel_not_found))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      :error ->
        json(conn, SlackResponse.error(:invalid_channel))
    end
  end

  def close(conn, _params), do: render_not_implemented(conn)
  def join(conn, _params), do: render_not_implemented(conn)
  def leave(conn, _params), do: render_not_implemented(conn)
  def kick(conn, _params), do: render_not_implemented(conn)
  def rename(conn, _params), do: render_not_implemented(conn)

  defp render_not_implemented(conn) do
    json(conn, SlackResponse.error(:not_implemented))
  end

  defp list_options(params, after_id) do
    limit =
      params
      |> Map.get("limit")
      |> parse_integer(200)
      |> clamp_limit()

    opts = [limit: limit]

    if after_id do
      Keyword.put(opts, :after_id, after_id)
    else
      opts
    end
  end

  defp clamp_limit(value) when is_integer(value) and value > 0, do: min(value, 200)
  defp clamp_limit(_), do: 100

  defp decode_cursor(nil), do: {:ok, nil}
  defp decode_cursor(""), do: {:ok, nil}

  defp decode_cursor(cursor) do
    case SlackId.decode_cursor(cursor) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :invalid_cursor}
    end
  end

  defp message_paging_opts(params) do
    limit =
      params
      |> Map.get("limit")
      |> parse_integer(100)
      |> clamp_limit()

    cursor = Map.get(params, "cursor")

    opts = [limit: limit]

    case decode_message_cursor(cursor) do
      {:ok, nil} -> {:ok, opts}
      {:ok, message_id} -> {:ok, Keyword.put(opts, :before_id, message_id)}
      {:error, :missing_cursor} -> {:ok, opts}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_message_cursor(nil), do: {:error, :missing_cursor}
  defp decode_message_cursor(""), do: {:error, :missing_cursor}

  defp decode_message_cursor(cursor) do
    case SlackId.decode_message_cursor(cursor) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :invalid_cursor}
    end
  end

  defp ensure_membership(conversation_id, profile_id) do
    case Messngr.ensure_membership(conversation_id, profile_id) do
      %Participant{} = participant -> {:ok, participant}
      _ -> {:error, :forbidden}
    end
  rescue
    _ -> {:error, :forbidden}
  end

  defp load_conversation(conversation_id, profile_id) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        {:error, :not_found}

      %Conversation{} = conversation ->
        conversation = Repo.preload(conversation, participants: [:profile])

        if Enum.any?(conversation.participants, &(&1.profile_id == profile_id)) do
          {:ok, hydrate_conversation(conversation, profile_id)}
        else
          {:error, :forbidden}
        end
    end
  end

  defp hydrate_conversation(%Conversation{} = conversation, profile_id) do
    participant = Enum.find(conversation.participants, &(&1.profile_id == profile_id))

    last_message =
      Message
      |> where(conversation_id: ^conversation.id)
      |> order_by([m], desc: m.inserted_at, desc: m.id)
      |> limit(1)
      |> Repo.one()
      |> case do
        nil -> nil
        %Message{} = message -> Repo.preload(message, :profile)
      end

    unread_count =
      Message
      |> where(conversation_id: ^conversation.id)
      |> maybe_filter_unread(participant)
      |> select([m], count(m.id))
      |> Repo.one()

    conversation
    |> Map.put(:last_message, last_message)
    |> Map.put(:unread_count, unread_count || 0)
  end

  defp maybe_filter_unread(query, %Participant{last_read_at: nil}), do: query

  defp maybe_filter_unread(query, %Participant{last_read_at: last_read_at}) do
    where(query, [m], m.inserted_at > ^last_read_at)
  end

  defp maybe_filter_unread(query, _), do: query

  defp fetch_required(params, key) do
    case Map.get(params, key) do
      nil -> {:error, :"missing_#{key}"}
      "" -> {:error, :"missing_#{key}"}
      value -> {:ok, value}
    end
  end

  defp decode_message_ts(ts) do
    case SlackTimestamp.decode_message_id(ts) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :invalid_ts}
    end
  end

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_value, default), do: default
end
