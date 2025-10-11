defmodule SlackApiWeb.Controllers.ChatApiController do
  use SlackApiWeb, :controller
  require Logger

  def init(opts \\ []) do
    Logger.info("Started ChatApiController with options #{inspect opts}")
  end

  def post_message() do
    #
  end

  def get_permalink() do
    #
  end

  def update() do
    #
  end

  def delete() do
    #
  end
end
