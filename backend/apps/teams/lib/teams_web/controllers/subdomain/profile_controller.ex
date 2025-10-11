defmodule TeamsWeb.Subdomain.ProfileController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn
  alias Teams.TenantModels.{Profile, ProfileRole, Role}

  def filter_profile_for_json(profile), do: Map.drop(Map.from_struct(profile), [:__meta__, :is_bot, :metadata])

  defp get_authed_context(conn) do
    tenant = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    profile = Profile.get_by_uid(tenant, uid)
    {tenant, profile}
  end

  def list(conn, params) do
    tenant = conn.private[:subdomain]
    everyone = Profile.list(tenant) |> Enum.map(fn x -> filter_profile_for_json(x) end)
    conn
      |> send_resp(200, Jason.encode!(everyone))
  end

  def create(conn, params) do
    {tenant, profile} = get_authed_context(conn)
    if is_nil(profile) do
      username = params["username"]
      first_name = params["first_name"]
      last_name = params["last_name"]
      claims = Guardian.Plug.current_claims(conn)
      profile = Profile.quick_create_profile(tenant, claims["sub"], username, first_name, last_name)
      {:ok, profile} = add_roles(tenant, Profile.load_roles(tenant, profile))
      rdata = filter_profile_for_json(profile)
      conn
        |> send_resp(200, Jason.encode!(rdata))
    else
      Logger.warning "Found profile from before: #{inspect profile}"
      conn
        |> send_resp(400, Jason.encode!(%{"error": "does already exist!"}))
    end
  end

  def update(conn, params) do
    {tenant, authed_profile} = get_authed_context(conn)
    profile_id = params["profile_id"]
    if profile_id == authed_profile.id do
      actual_update(conn, tenant, profile_id, params)
    else
      if Profile.can?(tenant, authed_profile, "can_update_other_profile") do
        actual_update(conn, tenant, profile_id, params)
      else
        conn
          |> send_resp(401, Jason.encode!(%{"error": "You're not allowed to update someone else's profile!"}))
          |> halt()
      end
    end
  end

  def get(conn, params) do
    tenant = conn.private[:subdomain]
    profile_id = params["profile_id"]
    profile = filter_profile_for_json(Profile.get_by_id(tenant, profile_id))
    conn |> send_resp(200, Jason.encode!(profile))
  end

  def delete(conn, params) do
    #
  end

  defp actual_update(conn, tenant, profile_id, params) do
    first_name = params["first_name"]
    last_name = params["last_name"]
    settings = params["settings"]
    attrs = %{first_name: first_name, last_name: last_name, settings: settings}
    old_profile = Profile.get_by_id(tenant, profile_id)
    {:ok, profile} = Profile.update(tenant, old_profile, attrs)
    rdata = filter_profile_for_json(profile)
    conn
      |> send_resp(200, Jason.encode!(rdata))
  end

  @spec add_roles(String.t(), %Profile{}) :: {:ok, %Profile{}} | {:error, String.t()}
  defp add_roles(tenant, profile) do
    dfl = Role.get_default(tenant)
    # Also add profile.uid to Teams.TenantTeam
    Teams.TenantTeam.append_members(tenant, [profile.uid])
    if Profile.count(tenant) == 1 do
      owner = Role.get_by_name(tenant, "Owner")
      ProfileRole.upsert_profile_roles(tenant, profile.id, [owner.id, dfl.id])
    else
      ProfileRole.upsert_profile_roles(tenant, profile.id, [dfl.id])
    end
  end
end
