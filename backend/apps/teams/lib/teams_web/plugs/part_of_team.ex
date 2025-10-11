defmodule TeamsWeb.Plugs.PartOfTeam do
  @behaviour Plug
  import Plug.Conn, only: [halt: 1, send_resp: 3]

  def init(_opts) do
  end

  def call(%Plug.Conn{} = conn, _opts) do
    subdomain = conn.private[:subdomain]
    claims = Guardian.Plug.current_claims(conn)
    profile = Teams.TenantModels.Profile.get_by_uid(subdomain, claims["sub"])
    if is_nil(profile) do
      conn
        |> send_resp(401, Jason.encode!(%{"error" => "you're not part of this team!"}))
        |> halt()
    else
      conn
    end
  end
end
