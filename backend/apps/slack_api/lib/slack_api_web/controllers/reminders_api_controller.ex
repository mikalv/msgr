defmodule SlackApiWeb.Controllers.RemindersApiController do
  use SlackApiWeb, :controller

  require Logger

  alias SlackApi.SlackResponse

  def init(opts \\ []) do
    Logger.info("Started RemindersApiController with options #{inspect(opts)}")
  end

  def info(conn, _params), do: render_not_implemented(conn)
  def list(conn, _params), do: render_not_implemented(conn)
  def add(conn, _params), do: render_not_implemented(conn)
  def complete(conn, _params), do: render_not_implemented(conn)
  def delete(conn, _params), do: render_not_implemented(conn)

  defp render_not_implemented(conn) do
    json(conn, SlackResponse.error(:not_implemented))
  end
end
