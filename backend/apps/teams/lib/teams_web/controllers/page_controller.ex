defmodule TeamsWeb.PageController do
  use TeamsWeb, :controller
  require Logger

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def create_team(conn, params) do
    name = params["team_name"]
    uid = params["uid"]
    desc = params["description"]
    if Teams.TenantsHelper.is_tenant_name_available(name) do
      Logger.debug "Tenant name #{name} seems available"
      Task.async(fn ->
        Teams.TenantsHelper.create_tenant(name, uid, desc)
        :ok
      end)
      render(conn, :created_team, layout: false)
    else
      render(conn, :error, layout: false, error_message: "Team name is already taken!")
    end
  end
end
