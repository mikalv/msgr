defmodule EdgeRouter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {EdgeRouter.MainProxy, []}
    ]
    Logger.info("Hello from EdgeRouter")


    Supervisor.start_link(children, strategy: :one_for_one, name: EdgeRouter.Supervisor)
  end
end
