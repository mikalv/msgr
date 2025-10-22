defmodule TeamsWeb.Subdomain.InvitationController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn
  alias Teams.TenantModels.{Invitation, Profile}

  def filter_invitation_for_json(inv), do: Map.drop(Map.from_struct(inv), [:__meta__, :updated_at, :inserted_at, :metadata])

  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile}
  end

  def list(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def get(conn, _params) do
    {_tenant, _profile} = get_authed_context(conn)
    conn |> send_resp(501, Jason.encode!(%{error: "not_implemented"}))
  end

  def create(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    if Profile.can?(tenant, profile, "can_invite_user") do
      case params["invitation_mode"] do
        "email" ->
          Logger.info "Requesting invite per email"
          # TODO: Validate email correctly
          {:ok, invitation} = Invitation.create_email_invitation(tenant, profile, params["email"])
          conn |> send_resp(200, Jason.encode!(filter_invitation_for_json(invitation)))

        "phone" ->
          Logger.info "Requesting invite per phone"
          # TODO: Validate msisdn correctly
          {:ok, invitation} = Invitation.create_msisdn_invitation(tenant, profile, params["msisdn"])
          conn |> send_resp(200, Jason.encode!(filter_invitation_for_json(invitation)))
      end
    else
      conn
      |> send_resp(401, Jason.encode!(%{error: "You don't have the roles or permission to create a new invitation!"}))
    end
  end

  def update(conn, _params) do
    conn |> send_resp(405, Jason.encode!(%{error: "method_not_allowed"}))
  end

  def delete(conn, _params) do
    conn |> send_resp(405, Jason.encode!(%{error: "method_not_allowed"}))
  end
end
