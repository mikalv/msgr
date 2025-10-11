defmodule TeamsWeb.Subdomain.PageController do
  use TeamsWeb, :controller
  require Logger
  import Plug.Conn

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    conn
    |> send_resp(200, "Your shit: #{inspect conn}")
  end

end
