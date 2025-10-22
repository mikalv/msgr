defmodule Messngr.Bridges.HealthReporter do
  @moduledoc """
  Periodically polls bridge daemons for runtime health snapshots and emits telemetry.

  The reporter wires the Elixir connectors to the language-specific bridge runtimes
  so operational dashboards can surface websocket status, pending event depth, and
  acknowledgement latency without bespoke polling glue per service.
  """

  use GenServer
  require Logger

  @type bridge_config :: %{
          optional(:name) => atom() | String.t(),
          required(:connector) => module(),
          optional(:connector_opts) => keyword(),
          optional(:request_payload) => map() | keyword(),
          optional(:request_opts) => keyword(),
          optional(:metadata) => map()
        }

  @doc """
  Starts the health reporter with the supplied configuration.
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, :timer.seconds(30))

    bridges =
      opts
      |> Keyword.get(:bridges, [])
      |> Enum.flat_map(&build_bridge/1)

    schedule_collect(0)

    {:ok, %{interval: interval, bridges: bridges}}
  end

  @impl true
  def handle_info(:collect, %{interval: interval, bridges: bridges} = state) do
    Enum.each(bridges, &collect_bridge/1)
    schedule_collect(interval)
    {:noreply, state}
  end

  defp schedule_collect(interval) when is_integer(interval) and interval >= 0 do
    Process.send_after(self(), :collect, interval)
  end

  defp schedule_collect(_invalid) do
    Process.send_after(self(), :collect, :timer.seconds(30))
  end

  defp build_bridge(%{connector: connector} = config) when is_atom(connector) do
    connector_opts = Map.get(config, :connector_opts, [])
    payload = normalise_payload(Map.get(config, :request_payload))
    request_opts = Map.get(config, :request_opts, [])
    metadata = Map.get(config, :metadata, %{})

    try do
      bridge = connector.new(connector_opts)
      name = normalise_name(Map.get(config, :name), bridge)

      [
        %{
          name: name,
          connector: connector,
          bridge: bridge,
          request_payload: payload,
          request_opts: request_opts,
          metadata: metadata
        }
      ]
    rescue
      error ->
        Logger.error("Failed to initialise bridge health reporter", connector: inspect(connector), error: inspect(error))
        []
    end
  end

  defp build_bridge(_invalid), do: []

  defp collect_bridge(%{connector: connector, bridge: bridge} = config) do
    payload = Map.get(config, :request_payload, %{})
    opts = Map.get(config, :request_opts, [])
    name = Map.fetch!(config, :name)
    metadata = Map.get(config, :metadata, %{})

    result =
      try do
        connector.health_snapshot(bridge, payload, opts)
      rescue
        error -> {:error, error}
      end

    case result do
      {:ok, snapshot} ->
        emit_metrics(name, snapshot, metadata)
      {:error, reason} ->
        Logger.warning("Bridge health snapshot failed", bridge: name, reason: inspect(reason))
    end
  end

  defp emit_metrics(name, snapshot, metadata) when is_map(snapshot) do
    status = fetch(snapshot, :status)
    summary = fetch(snapshot, :summary, %{})

    measurements = %{
      total_clients: coerce_int(fetch(summary, :total_clients)),
      connected_clients: coerce_int(fetch(summary, :connected_clients)),
      pending_events: coerce_int(fetch(summary, :pending_events)),
      acked_events: coerce_int(fetch(summary, :acked_events))
    }

    meta =
      metadata
      |> Map.put(:bridge, name)
      |> maybe_put(:status, status)

    :telemetry.execute([:messngr, :bridges, name, :health], measurements, meta)

    clients = List.wrap(fetch(snapshot, :clients, []))

    Enum.each(clients, fn client ->
      client_measurements = %{
        pending_events: coerce_int(fetch(client, :pending_events)),
        connected: bool_to_int(fetch(client, :connected))
      }

      client_meta =
        meta
        |> maybe_put(:instance, fetch(client, :instance) || fetch(client, :tenant_id))
        |> maybe_put(:user_id, fetch(client, :user_id))
        |> maybe_put(:workspace_id, fetch(client, :workspace_id) || fetch(client, :tenant_id))

      :telemetry.execute([:messngr, :bridges, name, :client_health], client_measurements, client_meta)
    end)
  end

  defp emit_metrics(_name, _snapshot, _metadata), do: :ok

  defp fetch(data, key, default \\ nil)
  defp fetch(data, key, default) when is_map(data) do
    Map.get(data, key, Map.get(data, to_string(key), default))
  end

  defp fetch(_data, _key, default), do: default

  defp normalise_payload(nil), do: %{}
  defp normalise_payload(params) when is_map(params), do: Map.new(params)
  defp normalise_payload(params) when is_list(params), do: Map.new(params)
  defp normalise_payload(_other), do: %{}

  defp normalise_name(nil, bridge) do
    bridge
    |> Map.get(:service)
    |> case do
      nil -> :unknown
      service -> service |> to_string() |> ensure_atom()
    end
  end

  defp normalise_name(name, _bridge) when is_atom(name), do: name
  defp normalise_name(name, _bridge) when is_binary(name), do: ensure_atom(name)
  defp normalise_name(_other, _bridge), do: :unknown

  defp ensure_atom(value) when is_atom(value), do: value

  defp ensure_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> String.to_atom(value)
    end
  end

  defp coerce_int(value) when is_integer(value), do: value
  defp coerce_int(value) when is_float(value), do: trunc(value)
  defp coerce_int(_other), do: 0

  defp bool_to_int(true), do: 1
  defp bool_to_int(_other), do: 0

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
