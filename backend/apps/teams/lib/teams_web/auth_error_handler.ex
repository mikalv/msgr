defmodule TeamsWeb.AuthErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler
  import Plug.Conn
  require Logger

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, opts) do
    Logger.warning "Authentication failure: type=#{inspect type} reason=#{inspect reason} opts=#{inspect opts}"
    conn
      |> send_resp(401, "Access denied bitch")
  end
end
