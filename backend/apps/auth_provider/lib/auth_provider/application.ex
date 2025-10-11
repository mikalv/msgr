defmodule AuthProvider.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AuthProvider.Repo,
      AuthProvider.Telemetry,
      {Phoenix.PubSub, name: AuthProvider.PubSub},
      # Start a worker by calling: AuthProvider.Worker.start_link(arg)
      # {AuthProvider.Worker, arg},
      {Guardian.DB.Sweeper, []},
      # Start to serve requests, typically the last entry
      AuthProvider.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AuthProvider.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AuthProvider.Endpoint.config_change(changed, removed)
    :ok
  end
end
