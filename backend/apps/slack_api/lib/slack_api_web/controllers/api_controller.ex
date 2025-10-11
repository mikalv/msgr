defmodule SlackApiWeb.Controllers.ApiController do
  use SlackApiWeb, :controller
  require Logger

  def init(opts \\ []) do
    Logger.info("Started ApiController with options #{inspect(opts)}")
    :ok
  end

  def status_test(conn, _params) do
    conn
    |> send_resp(200, "Yo :)")
  end
end
