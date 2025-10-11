defmodule TeamsWeb.Subdomain.ConversationsController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn
  alias Teams.TenantModels.{Conversation, Profile}

  def filter_conv_for_json(conv), do: Map.drop(Map.from_struct(conv), [:__meta__, :updated_at, :metadata])

  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile}
  end

  def list(conn, params) do
    {tenant, profile} = get_authed_context(conn)
  end

  def create(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    attrs = params["options"]
    members = Map.get(params, "members", [])
    case Conversation.create_conversation(tenant, profile, attrs, members) do
      {:ok, conv} ->
        conn |> send_resp(200, Jason.encode!(filter_conv_for_json(conv)))
      {:error, err} ->
        Logger.error "Error while trying to create conversation: #{inspect err}"
        conn |> send_resp(500, Jason.encode!(%{"error": "Sorry! try again later"}))
    end
  end

  def update(conn, params) do
    tenant = conn.private[:subdomain]
    #
  end

  def get(conn, params) do
    tenant = conn.private[:subdomain]
    conv_id = params["conversation_id"]
    conv = Conversation.get_by_id(tenant, conv_id)
    if is_nil(conv) do
      conn |> send_resp(400, Jason.encode!(%{"error": "Sorry! Conversation don't seem to exist!"}))
    else
      conn |> send_resp(200, Jason.encode!(filter_conv_for_json(conv)))
    end
  end

  def delete(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def history(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def close(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def join(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def kick(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def leave(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def members(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def replies(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end

  def invite(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    conversation_id = params["conversation_id"]
  end
end
