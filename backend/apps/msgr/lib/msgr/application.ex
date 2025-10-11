defmodule Messngr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Messngr.Repo,
      {DNSCluster, query: Application.get_env(:msgr, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Messngr.PubSub},
      Messngr.Calls.CallRegistry,
      #{Guardian.DB.SweeperServer, []},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Messngr.Finch}
      # Start a worker by calling: Messngr.Worker.start_link(arg)
      # {Messngr.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Messngr.Supervisor)
  end
end
