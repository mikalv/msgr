defmodule SlackApiWeb.Controllers.ChatApiController do
  use SlackApiWeb, :controller

  require Logger

  alias Messngr
  alias Messngr.Chat.Conversation
  alias SlackApi.{SlackAdapter, SlackId, SlackResponse, SlackTimestamp}

  def init(opts \\ []) do
    Logger.info("Started ChatApiController with options #{inspect(opts)}")
  end

  def post_message(conn, params) do
    current_profile = conn.assigns.current_profile
    current_account = conn.assigns.current_account

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, text} <- fetch_required(params, "text"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, message} <-
           Messngr.send_message(conversation_id, current_profile.id, %{"body" => text}) do
      conversation_stub = %Conversation{id: conversation_id, kind: kind}

      payload =
        SlackAdapter.message(message,
          account: current_account,
          conversation: conversation_stub
        )

      response =
        SlackResponse.success(%{
          channel: SlackId.conversation({kind, conversation_id}),
          ts: payload[:ts],
          message: payload
        })

      json(conn, response)
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_text} ->
        json(conn, SlackResponse.error(:missing_text))

      :error ->
        json(conn, SlackResponse.error(:invalid_channel))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end

  def get_permalink(conn, params) do
    current_account = conn.assigns.current_account

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, {_kind, conversation_id} = conversation} <- SlackId.decode_conversation(channel),
         {:ok, message_ts} <- fetch_required(params, "message_ts"),
         {:ok, message_id} <- SlackTimestamp.decode_message_id(message_ts) do
      permalink =
        SlackApiWeb.Endpoint.url() <>
          "/conversations/#{conversation_id}/messages/#{message_id}"

      response =
        SlackResponse.success(%{
          channel: SlackId.conversation(conversation),
          permalink: permalink,
          team_id: SlackId.team(current_account)
        })

      json(conn, response)
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_message_ts} ->
        json(conn, SlackResponse.error(:missing_message_ts))

      :error ->
        json(conn, SlackResponse.error(:invalid_ts))
    end
  end

  def update(conn, params) do
    current_profile = conn.assigns.current_profile
    current_account = conn.assigns.current_account

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, text} <- fetch_required(params, "text"),
         {:ok, ts} <- fetch_required(params, "ts"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, message_id} <- SlackTimestamp.decode_message_id(ts),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, message} <-
           Messngr.update_message(conversation_id, current_profile.id, message_id, %{
             "body" => text
           }) do
      conversation_stub = %Conversation{id: conversation_id, kind: kind}

      payload =
        SlackAdapter.message(message,
          account: current_account,
          conversation: conversation_stub
        )

      response =
        SlackResponse.success(%{
          channel: SlackId.conversation({kind, conversation_id}),
          ts: payload[:ts],
          message: payload
        })

      json(conn, response)
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_text} ->
        json(conn, SlackResponse.error(:missing_text))

      {:error, :missing_ts} ->
        json(conn, SlackResponse.error(:missing_ts))

      :error ->
        json(conn, SlackResponse.error(:invalid_ts))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end

  def delete(conn, params) do
    current_profile = conn.assigns.current_profile

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, ts} <- fetch_required(params, "ts"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, message_id} <- SlackTimestamp.decode_message_id(ts),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, _message} <-
           Messngr.delete_message(conversation_id, current_profile.id, message_id) do
      json(
        conn,
        SlackResponse.success(%{channel: SlackId.conversation({kind, conversation_id}), ts: ts})
      )
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_ts} ->
        json(conn, SlackResponse.error(:missing_ts))

      :error ->
        json(conn, SlackResponse.error(:invalid_ts))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end

  defp ensure_membership(conversation_id, profile_id) do
    Messngr.ensure_membership(conversation_id, profile_id)
    {:ok, :member}
  rescue
    _ -> {:error, :forbidden}
  end

  defp fetch_required(params, key) do
    case Map.get(params, key) do
      nil -> {:error, :"missing_#{key}"}
      "" -> {:error, :"missing_#{key}"}
      value -> {:ok, value}
    end
  end
end
