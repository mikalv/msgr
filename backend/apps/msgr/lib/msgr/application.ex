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
        {Finch, name: Messngr.Finch, pools: %{
          "https://api.sandbox.push.apple.com" => [protocols: [:http2]],
          "https://api.push.apple.com" => [protocols: [:http2]]
        }},
        retention_pruner_child,
        watcher_pruner_child
        # Start a worker by calling: Messngr.Worker.start_link(arg)
        # {Messngr.Worker, arg}
      ]
    # Filter out nil children (disabled pruners return nil)
    children = Enum.reject(children, &is_nil/1)
    Logger.info("✅ Base children list built with #{length(children)} items")

    # TODO: Re-enable when Messngr.Transport.Noise.Registry module is implemented
    # children = children |> Kernel.++(maybe_noise_registry_child())

    children = children |> Kernel.++(maybe_bridge_health_child())

    # TODO: Re-enable when gRPC proto/endpoint modules are compiled
    # children = children |> Kernel.++(maybe_rust_gateway_grpc_server())

    Logger.info("🔧 Starting supervisor with #{length(children)} children...")
    Logger.info("Children to start: #{inspect(Enum.map(children, &child_name/1))}")

    result = Supervisor.start_link(children, strategy: :one_for_one, name: Messngr.Supervisor)

    Logger.info("✅ Supervisor started successfully!")

    # Run ALL pending migrations on startup (idempotent)
    spawn(fn ->
      Process.sleep(1_000)

      try do
        # Standard Ecto migrations (msgr app)
        Ecto.Migrator.run(Messngr.Repo, Application.app_dir(:msgr, "priv/repo/migrations"), :up, all: true)
        Logger.info("✅ Msgr migrations complete")

        # Tenant migrations (per-team schemas)
        Teams.Tenancy.migrate_all_tenants()
        Logger.info("✅ Tenant migrations complete")
      rescue
        e ->
          Logger.warning("Could not run tenant migrations: #{inspect(e)}")
      end
    end)

    # Seed built-in app commands (idempotent)
    spawn(fn ->
      Process.sleep(2_000)

      try do
        Messngr.Apps.BuiltinCommands.seed!()
      rescue
        e ->
          Logger.warning("Could not seed built-in commands: #{inspect(e)}")
      end
    end)

    # Ensure the media storage bucket exists (idempotent)
    spawn(fn ->
      Process.sleep(3_000)

      try do
        Messngr.Media.Storage.ensure_bucket!(Messngr.Media.Storage.bucket())
      rescue
        e ->
          Logger.warning("Could not ensure media bucket: #{inspect(e)}")
      end
    end)

    result
  end

  defp child_name({mod, _}), do: mod
  defp child_name(mod) when is_atom(mod), do: mod
  defp child_name(other), do: inspect(other)

  defp maybe_noise_registry_child do
    opts = Application.get_env(:msgr, :noise_session_registry, [])

    if Keyword.get(opts, :enabled, false) and Code.ensure_loaded?(Messngr.Transport.Noise.Registry) do
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

    if Application.get_env(:msgr, :rust_gateway_grpc_enabled, false) do
      [
        {GRPC.Server.Supervisor,
         endpoint: Messngr.RustGateway.Endpoint, port: port, start_server: true}
      ]
    else
      []
    end
  end
end
