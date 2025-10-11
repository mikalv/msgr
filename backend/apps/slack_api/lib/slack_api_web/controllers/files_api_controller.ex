defmodule SlackApiWeb.Controllers.FilesApiController do
  use SlackApiWeb, :controller

  require Logger

  alias SlackApi.SlackResponse

  def init(opts \\ []) do
    Logger.info("Started FilesApiController with options #{inspect(opts)}")
  end

  def info(conn, _params), do: render_not_implemented(conn)
  def list(conn, _params), do: render_not_implemented(conn)
  def upload(conn, _params), do: render_not_implemented(conn)
  def delete(conn, _params), do: render_not_implemented(conn)
  def sharedPublicURL(conn, _params), do: render_not_implemented(conn)
  def revokePublicURL(conn, _params), do: render_not_implemented(conn)
  def remote_add(conn, _params), do: render_not_implemented(conn)
  def remote_info(conn, _params), do: render_not_implemented(conn)
  def remote_list(conn, _params), do: render_not_implemented(conn)
  def remote_remove(conn, _params), do: render_not_implemented(conn)
  def remote_share(conn, _params), do: render_not_implemented(conn)
  def remote_update(conn, _params), do: render_not_implemented(conn)

  defp render_not_implemented(conn) do
    json(conn, SlackResponse.error(:not_implemented))
  end
end
