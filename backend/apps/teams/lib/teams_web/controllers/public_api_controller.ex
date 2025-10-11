defmodule TeamsWeb.PublicApiController do
  use TeamsWeb, :controller
  import Plug.Conn
  require Logger

  def filter_team_for_json(team), do: Map.drop(Map.from_struct(team), [:__meta__, :metadata])
  def filter_profile_for_json(profile), do: Map.drop(Map.from_struct(profile), [:__meta__, :is_bot, :metadata])


  def select_team(conn, params) do
    {uid, claims} = get_authed_context(conn)
    ttstr = params["team_name"]
    case Teams.TenantTeam.am_i_a_member?(ttstr, uid) do
      {true, team} ->
        profile = Teams.TenantModels.Profile.get_by_uid(ttstr, uid)
        # Attach profile id as claim IF we have a profile..
        # Senarios:
        # - If it's onboarding, the profile isn't created as;
        # - - the team owner hasn't created a profile yet
        # - - the user beeing invited hasn't created a profile yet
        # - If it's login the profile should exist already
        profile_id = if is_nil(profile) do
          nil
        else
          profile.id
        end
        {:ok, token, claims} = AuthProvider.Guardian.issue_token_for_team(ttstr, team.id, uid, profile_id)
        Logger.info "Issued out team token with claims #{inspect claims}"
        if is_nil(profile) do
          conn |> send_resp(200, Jason.encode!(%{
            "status" => "ok",
            "teamAccessToken" => token,
            "teamName" => ttstr,
            "profile" => nil,
            "next_action" => "create_profile"}))
        else
          conn |> send_resp(200, Jason.encode!(%{
            "status" => "ok",
            "teamAccessToken" => token,
            "teamName" => ttstr,
            "profile" => filter_profile_for_json(profile),
            "next_action" => "chat"}))
        end
      {false, nil} ->
        Logger.warning "User uid=#{uid} attempted to authenticate to a team (#{ttstr}) which the user isn't a member of."
        conn |> send_resp(401, Jason.encode!(%{"status" => "error", "error" => "You're not a member of this team!"}))
    end
  end

  def my_teams(conn, _params) do
    {uid, _claims} = get_authed_context(conn)
    myteams = Teams.TenantTeam.my_teams(uid) |> Enum.map(fn x -> filter_team_for_json(x) end)
    conn
      |> send_resp(200, Jason.encode!(%{"status" => "ok", "teams" => myteams}))
  end

  def create_team(conn, params) do
    name = params["team_name"]
    uid = params["uid"]
    desc = params["description"]
    if Teams.TenantsHelper.is_tenant_name_available(name) do
      Logger.debug "Tenant name #{name} seems available"
      # Might need to run async in future
      {:ok, team} = Teams.TenantsHelper.create_tenant(name, uid, desc)
      conn |> send_resp(200, Jason.encode!(%{"status" => "ok", "team" => filter_team_for_json(team)}))
    else
      conn |> send_resp(400, Jason.encode!(%{"status" => "error", "error" => "Team name is already taken!"}))
    end
  end

  def get_team(_conn, _params) do
  end

  def update_team(_conn, _params) do
  end

  def delete_team(_conn, _params) do
  end

  defp get_authed_context(conn) do
    claims = Guardian.Plug.current_claims(conn)
    uid = claims["sub"]
    {uid, claims}
  end
end
