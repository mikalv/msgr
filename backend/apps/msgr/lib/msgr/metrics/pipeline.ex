defmodule Messngr.Metrics.Pipeline do
  @moduledoc """
  Attaches telemetry handlers and forwards derived metrics to reporters.

  Other parts of the system should emit the public telemetry events exposed by
  this module. The pipeline translates those into reporter friendly metrics such
  as delivery latency or app start duration.
  """

  use GenServer

  @delivery_latency_event [:msgr, :chat, :delivery, :latency]
  @delivery_rate_event [:msgr, :chat, :delivery, :rate]
  @app_start_event [:msgr, :app, :startup]
  @composer_event [:msgr, :composer, :render]

  @doc """
  Starts the pipeline and attaches telemetry handlers.
  """
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    gen_opts = if is_nil(name), do: [], else: [name: name]
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @impl true
  def init(opts) do
    reporter = resolve_reporter(opts)
    state = %{reporter: reporter, handlers: []}

    handlers =
      [
        {@delivery_latency_event, &handle_latency/4},
        {@delivery_rate_event, &handle_rate/4},
        {@app_start_event, &handle_app_start/4},
        {@composer_event, &handle_composer/4}
      ]
      |> Enum.map(&attach_handler(&1, state))

    {:ok, %{state | handlers: handlers}}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.handlers, fn {id, event} -> :telemetry.detach({__MODULE__, id, event}) end)
    :ok
  end

  @doc """
  Emits a delivery latency measurement in milliseconds.
  """
  def emit_delivery_latency(duration_ms, metadata \\ %{}) do
    :telemetry.execute(@delivery_latency_event, %{duration_ms: duration_ms}, metadata)
  end

  @doc """
  Emits a delivery rate measurement.
  """
  def emit_delivery_rate(delivered, attempted, metadata \\ %{}) do
    :telemetry.execute(@delivery_rate_event, %{delivered: delivered, attempted: attempted}, metadata)
  end

  @doc """
  Emits an app start duration measurement.
  """
  def emit_app_start(duration_ms, metadata \\ %{}) do
    :telemetry.execute(@app_start_event, %{duration_ms: duration_ms}, metadata)
  end

  @doc """
  Emits a composer render duration measurement.
  """
  def emit_composer_render(duration_ms, metadata \\ %{}) do
    :telemetry.execute(@composer_event, %{duration_ms: duration_ms}, metadata)
  end

  defp attach_handler({event, handler}, state) do
    id = System.unique_integer([:positive])
    :telemetry.attach({__MODULE__, id, event}, event, handler, state)
    {id, event}
  end

  defp handle_latency(_event, %{duration_ms: duration}, metadata, %{reporter: reporter}) do
    report(reporter, :delivery_latency, %{duration_ms: duration}, metadata)
  end

  defp handle_rate(_event, %{delivered: delivered, attempted: attempted}, metadata, %{reporter: reporter}) do
    rate = if attempted > 0, do: delivered / attempted, else: 0.0
    measurement = %{delivered: delivered, attempted: attempted, success_rate: rate}
    report(reporter, :delivery_rate, measurement, metadata)
  end

  defp handle_app_start(_event, %{duration_ms: duration}, metadata, %{reporter: reporter}) do
    report(reporter, :app_start, %{duration_ms: duration}, metadata)
  end

  defp handle_composer(_event, %{duration_ms: duration}, metadata, %{reporter: reporter}) do
    report(reporter, :composer_render, %{duration_ms: duration}, metadata)
  end

  defp report(reporter, metric, measurement, metadata) when is_atom(reporter) do
    reporter.handle_metric(metric, measurement, metadata)
  end

  defp report(reporter, metric, measurement, metadata) when is_function(reporter, 3) do
    reporter.(metric, measurement, metadata)
  end

  defp resolve_reporter(opts) do
    case Keyword.get(opts, :reporter) do
      nil ->
        Application.get_env(:msgr, __MODULE__, [])
        |> Keyword.get(:reporter, Messngr.Metrics.Reporter.Log)

      reporter -> reporter
    end
  end
end
