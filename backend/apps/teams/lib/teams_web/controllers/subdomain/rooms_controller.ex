defmodule TeamsWeb.Subdomain.RoomsController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn
  alias Teams.TenantModels.{Profile, Room}
  alias TeamsWeb.MiddleLayer.RoomLayer

  def filter_room_for_json(room), do: Map.drop(Map.from_struct(room), [:__meta__, :updated_at, :inserted_at, :metadata])

  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile}
  end

  def list(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    Room.list_with_me(tenant, profile)
  end

  def create(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    attrs = params["options"]
    members = Map.get(params, "members", [])

    case RoomLayer.create_room(tenant, profile.id, attrs, members) do
      {:ok, room} ->
        conn |> send_resp(200, Jason.encode!(filter_room_for_json(room)))

      {:error, err} ->
        Logger.error "Error while trying to create room: #{inspect err}"
        conn |> send_resp(500, Jason.encode!(%{"error": "Sorry! try again later"}))

      {:permission_error, err} ->
        conn |> send_resp(401, Jason.encode!(%{"error": "You don't have the roles or permission to create a new room! (#{err})"}))
    end
  end

  def update(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def get(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def delete(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def history(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def close(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def join(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def kick(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def leave(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def members(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def replies(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end

  def invite(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    room_id = params["room_id"]
  end
end
