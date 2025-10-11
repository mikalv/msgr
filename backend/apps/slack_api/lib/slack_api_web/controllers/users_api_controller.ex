defmodule SlackApiWeb.Controllers.UsersApiController do
  use SlackApiWeb, :controller
  require Logger

  def info() do
    #
  end

  def list() do
    #
  end

  def identity(conn, _params) do
    conn
    |> send_resp(200, "hmmd")
  end

  def lookupByEmail() do
    #
  end

  def setPresence() do
    #
  end

  def getPresence() do
    #
  end

  def setPhoto() do
    #
  end
end
