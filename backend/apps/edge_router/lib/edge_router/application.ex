defmodule EdgeRouter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("🌐 Starting EdgeRouter.Application...")

    children = [
      {EdgeRouter.MainProxy, []}
    ]
    Logger.info("📦 EdgeRouter children prepared: #{inspect(children)}")

    Logger.info("🔧 Starting EdgeRouter supervisor...")
    result = Supervisor.start_link(children, strategy: :one_for_one, name: EdgeRouter.Supervisor)

    Logger.info("✅ EdgeRouter supervisor started successfully!")
    result
  end
end
