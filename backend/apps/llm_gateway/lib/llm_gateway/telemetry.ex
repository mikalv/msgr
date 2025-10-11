defmodule LlmGateway.Telemetry do
  @moduledoc """
  Centralises telemetry events emitted by the gateway.
  """

  use GenServer
  require Logger

  @type event :: :request_build_started | :request_build_finished | :provider_call_started | :provider_call_finished
  @events [:request_build_started, :request_build_finished, :provider_call_started, :provider_call_finished]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :telemetry.attach_many(__MODULE__, telemetry_events(), &__MODULE__.handle_event/4, %{})
    |> case do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end

    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach(__MODULE__)
    :ok
  end

  @doc """
  Emits a telemetry event.
  """
  @spec emit(event(), map()) :: :ok
  def emit(event, metadata \\ %{}) when event in @events do
    :telemetry.execute([:llm_gateway, event], %{}, metadata)
    :ok
  end

  @doc false
  def handle_event([:llm_gateway, event], measurements, metadata, _config) do
    Logger.debug("llm_gateway_event", event: event, measurements: measurements, metadata: metadata)
  end

  defp telemetry_events do
    for event <- @events, do: [:llm_gateway, event]
  end
end
