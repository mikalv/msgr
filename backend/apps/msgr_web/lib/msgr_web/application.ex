defmodule MessngrWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    prometheus_options =
      Application.get_env(:msgr_web, :prometheus, [])
      |> Enum.into(%{})

    prometheus_child =
      case prometheus_options do
        %{enabled: true} ->
          metrics = MessngrWeb.Telemetry.metrics()
          name = Map.get(prometheus_options, :name, :prometheus_metrics)
          port = Map.get(prometheus_options, :port, 9_568)

          {TelemetryMetricsPrometheus,
           [
             metrics: metrics,
             name: name,
             port: port
           ]}

        _ ->
          nil
      end

    children =
      [
        MessngrWeb.Telemetry,
        prometheus_child,
        # Start a worker by calling: MessngrWeb.Worker.start_link(arg)
        # {MessngrWeb.Worker, arg},
        # Start to serve requests, typically the last entry
        MessngrWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MessngrWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MessngrWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
