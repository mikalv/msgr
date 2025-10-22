defmodule TeamsWeb.Subdomain.RoomsController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn
  alias Teams.TenantModels.{Profile, Room}
  alias TeamsWeb.MiddleLayers.RoomLayer

  def filter_room_for_json(room), do: Map.drop(Map.from_struct(room), [:__meta__, :updated_at, :inserted_at, :metadata])

  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile}
  end

  def list(conn, _params) do
    {tenant, profile} = get_authed_context(conn)
    rooms = Room.list_with_me(tenant, profile) |> Enum.map(&filter_room_for_json/1)
    conn |> send_resp(200, Jason.encode!(rooms))
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
        conn |> send_resp(500, Jason.encode!(%{error: "Sorry! try again later"}))

      {:permission_error, err} ->
        conn |> send_resp(401, Jason.encode!(%{error: "You don't have the roles or permission to create a new room! (#{err})"}))
    end
  end

  def update(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(405, Jason.encode!(%{error: "method_not_allowed"}))
  end

  def get(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def delete(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(405, Jason.encode!(%{error: "method_not_allowed"}))
  end

  def history(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def close(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def join(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def kick(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def leave(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def members(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def replies(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def invite(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end
end
