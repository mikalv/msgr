defmodule TeamsWeb.Plugs.ExistingTeam do
  @behaviour Plug
  require Logger

  import Plug.Conn, only: [put_private: 3, halt: 1, send_resp: 3]
  # Logger.error(Exception.format(:error, e, __STACKTRACE__))

  def init(_opts) do
  end

  def call(%Plug.Conn{} = conn, _opts) do
    subdomain = conn.private[:subdomain]
    try do
      team = Teams.TenantTeam.get_team!(subdomain)
      Logger.debug "Found team for subdomain #{subdomain} : #{inspect team}"
      conn
        |> put_private(:tenant, team.name)
    rescue
      _e in Ecto.NoResultsError ->
        conn
          |> send_resp(400, "Teams don't exist!")
          |> halt()
    end
  end
end
