defmodule MessngrWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    require Logger
    Logger.info("🌟 Starting MessngrWeb.Application...")

    Logger.info("📦 Initializing prometheus_child...")
    prometheus_child =
      :msgr_web
      |> Application.get_env(:prometheus, [])
      |> prometheus_child_spec()
    Logger.info("✅ prometheus_child initialized: #{inspect(prometheus_child)}")

    Logger.info("📦 Building MessngrWeb children list...")
    children =
      [
        MessngrWeb.Telemetry,
        prometheus_child,
        MessngrWeb.Presence,
        # Start a worker by calling: MessngrWeb.Worker.start_link(arg)
        # {MessngrWeb.Worker, arg},
        # Start to serve requests, typically the last entry
        MessngrWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)
    Logger.info("✅ MessngrWeb children list built with #{length(children)} items")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessngrWeb.Supervisor]

    Logger.info("🔧 Starting MessngrWeb supervisor...")
    result = Supervisor.start_link(children, opts)

    Logger.info("✅ MessngrWeb supervisor started successfully!")
    result
  end

  @doc false
  @spec prometheus_child_spec(keyword() | map()) :: Supervisor.child_spec() | nil
  def prometheus_child_spec(nil), do: nil

  def prometheus_child_spec(options) when is_list(options) or is_map(options) do
    options
    |> Enum.into(%{})
    |> build_prometheus_child()
  end

  defp build_prometheus_child(%{enabled: true} = options) do
    metrics = MessngrWeb.Telemetry.metrics()
    name = Map.get(options, :name, :prometheus_metrics)
    port = Map.get(options, :port, 9_568)

    {TelemetryMetricsPrometheus,
     [
       metrics: metrics,
       name: name,
       port: port
     ]}
  end

  defp build_prometheus_child(_options), do: nil

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MessngrWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
