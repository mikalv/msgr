defmodule Messngr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("🚀 Starting Messngr.Application...")

    Logger.info("📦 Initializing retention_pruner_child...")
    retention_pruner_child =
      :msgr
      |> Application.get_env(Messngr.Media.RetentionPruner, [])
      |> Messngr.Media.RetentionPruner.child_spec()
    Logger.info("✅ retention_pruner_child initialized")

    Logger.info("📦 Initializing watcher_pruner_child...")
    watcher_pruner_child =
      :msgr
      |> Application.get_env(Messngr.Chat.WatcherPruner, [])
      |> Messngr.Chat.WatcherPruner.child_spec()
    Logger.info("✅ watcher_pruner_child initialized")

    Logger.info("📦 Building base children list...")
    children =
      [
        Messngr.FeatureFlags,
        Messngr.Metrics.Pipeline,
        Messngr.Repo,
        {DNSCluster, query: Application.get_env(:msgr, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Messngr.PubSub},
        Messngr.Calls.CallRegistry,
        # {Guardian.DB.SweeperServer, []},
        # Start the Finch HTTP client for sending emails
        {Finch, name: Messngr.Finch},
        retention_pruner_child,
        watcher_pruner_child
        # Start a worker by calling: Messngr.Worker.start_link(arg)
        # {Messngr.Worker, arg}
      ]
    Logger.info("✅ Base children list built with #{length(children)} items")

    Logger.info("📦 Adding maybe_noise_registry_child...")
    children = children |> Kernel.++(maybe_noise_registry_child())
    Logger.info("✅ After noise registry: #{length(children)} children")

    Logger.info("📦 Adding maybe_bridge_health_child...")
    children = children |> Kernel.++(maybe_bridge_health_child())
    Logger.info("✅ After bridge health: #{length(children)} children")

    Logger.info("📦 Adding maybe_rust_gateway_grpc_server...")
    children = children |> Kernel.++(maybe_rust_gateway_grpc_server())
    Logger.info("✅ After gRPC server: #{length(children)} children")

    Logger.info("🔧 Starting supervisor with #{length(children)} children...")
    Logger.info("Children to start: #{inspect(Enum.map(children, &child_name/1))}")

    result = Supervisor.start_link(children, strategy: :one_for_one, name: Messngr.Supervisor)

    Logger.info("✅ Supervisor started successfully!")
    result
  end

  defp child_name({mod, _}), do: mod
  defp child_name(mod) when is_atom(mod), do: mod
  defp child_name(other), do: inspect(other)

  defp maybe_noise_registry_child do
    opts = Application.get_env(:msgr, :noise_session_registry, [])

    if Keyword.get(opts, :enabled, true) do
      registry_opts = Keyword.drop(opts, [:enabled])
      [{Messngr.Transport.Noise.Registry, registry_opts}]
    else
      []
    end
  end

  defp maybe_bridge_health_child do
    case Application.get_env(:msgr, :bridge_health_reporter) do
      opts when is_list(opts) ->
        if Keyword.get(opts, :enabled, false) do
          reporter_opts = Keyword.drop(opts, [:enabled])
          [{Messngr.Bridges.HealthReporter, reporter_opts}]
        else
          []
        end

      _other ->
        []
    end
  end

  defp maybe_rust_gateway_grpc_server do
    # Start gRPC server for Rust Gateway to call
    # Listens on port configured in :rust_gateway_server_port (default 50052)
    port = Application.get_env(:msgr, :rust_gateway_server_port, 50052)

    if Application.get_env(:msgr, :rust_gateway_grpc_enabled, true) do
      [
        {GRPC.Server.Supervisor,
         endpoint: Messngr.RustGateway.Endpoint, port: port, start_server: true}
      ]
    else
      []
    end
  end
end
