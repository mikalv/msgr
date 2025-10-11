defmodule SlackApiWeb.Controllers.ReactionsApiController do
  use SlackApiWeb, :controller

  require Logger

  alias Messngr
  alias SlackApi.{SlackId, SlackResponse, SlackTimestamp}

  def init(opts \\ []) do
    Logger.info("Started ReactionsApiController with options #{inspect(opts)}")
  end

  def get(conn, _params), do: render_not_implemented(conn)
  def list(conn, _params), do: render_not_implemented(conn)

  def add(conn, params) do
    current_profile = conn.assigns.current_profile

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, ts} <- fetch_required(params, "timestamp"),
         {:ok, name} <- fetch_required(params, "name"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, message_id} <- SlackTimestamp.decode_message_id(ts),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, reaction} <-
           Messngr.react_to_message(conversation_id, current_profile.id, message_id, name) do
      response =
        SlackResponse.success(%{
          channel: SlackId.conversation({kind, conversation_id}),
          timestamp: ts,
          reaction: %{
            name: reaction.emoji,
            user: SlackId.profile(current_profile.id)
          },
          item_user: SlackId.profile(current_profile.id),
          item: %{
            type: "message",
            channel: SlackId.conversation({kind, conversation_id}),
            ts: ts
          }
        })

      json(conn, response)
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_timestamp} ->
        json(conn, SlackResponse.error(:missing_timestamp))

      {:error, :missing_name} ->
        json(conn, SlackResponse.error(:missing_name))

      :error ->
        json(conn, SlackResponse.error(:invalid_ts))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end

  def remove(conn, params) do
    current_profile = conn.assigns.current_profile

    with {:ok, channel} <- fetch_required(params, "channel"),
         {:ok, ts} <- fetch_required(params, "timestamp"),
         {:ok, name} <- fetch_required(params, "name"),
         {:ok, {kind, conversation_id}} <- SlackId.decode_conversation(channel),
         {:ok, message_id} <- SlackTimestamp.decode_message_id(ts),
         {:ok, _member} <- ensure_membership(conversation_id, current_profile.id),
         {:ok, _status} <-
           Messngr.remove_reaction(conversation_id, current_profile.id, message_id, name) do
      json(
        conn,
        SlackResponse.success(%{
          channel: SlackId.conversation({kind, conversation_id}),
          timestamp: ts
        })
      )
    else
      {:error, :missing_channel} ->
        json(conn, SlackResponse.error(:missing_channel))

      {:error, :missing_timestamp} ->
        json(conn, SlackResponse.error(:missing_timestamp))

      {:error, :missing_name} ->
        json(conn, SlackResponse.error(:missing_name))

      :error ->
        json(conn, SlackResponse.error(:invalid_ts))

      {:error, :forbidden} ->
        json(conn, SlackResponse.error(:not_in_channel))

      {:error, reason} ->
        json(conn, SlackResponse.error(reason))
    end
  end

  defp render_not_implemented(conn) do
    json(conn, SlackResponse.error(:not_implemented))
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
