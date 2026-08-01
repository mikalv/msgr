defmodule Messngr.Media.VirusScan.Worker do
  @moduledoc """
  Bounded virus-scan job queue with concurrency limits.

  Prevents authenticated clients from exhausting API/ClamAV resources by
  flooding `complete` with unbounded `Task.Supervisor` workers.
  """

  use GenServer
  require Logger

  @default_max_concurrency 2
  @default_max_queue 100

  @type job :: {prefix :: String.t(), upload_id :: term()}

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Enqueue a scan job.

  Returns:
  - `:ok` when accepted (or already queued/running for the same upload)
  - `{:error, :queue_full}` when the pending queue is at capacity
  - `{:error, :worker_unavailable}` when the worker is not running
  """
  @spec enqueue(String.t(), term()) :: :ok | {:error, :queue_full | :worker_unavailable}
  def enqueue(prefix, upload_id) when is_binary(prefix) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :worker_unavailable}

      pid ->
        GenServer.call(pid, {:enqueue, prefix, upload_id}, 5_000)
    end
  end

  @doc "Current queue depth and in-flight count (for tests/metrics)."
  def stats do
    case Process.whereis(__MODULE__) do
      nil -> %{queued: 0, inflight: 0, max_concurrency: 0, max_queue: 0}
      pid -> GenServer.call(pid, :stats)
    end
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       queue: :queue.new(),
       queued: MapSet.new(),
       inflight: %{},
       inflight_ids: MapSet.new(),
       max_concurrency: Keyword.get(opts, :max_concurrency),
       max_queue: Keyword.get(opts, :max_queue)
     }}
  end

  @impl true
  def handle_call({:enqueue, prefix, upload_id}, _from, state) do
    key = {prefix, upload_id}
    {max_concurrency, max_queue} = limits(state)
    capacity = max_concurrency + max_queue
    load = map_size(state.inflight) + :queue.len(state.queue)

    cond do
      MapSet.member?(state.queued, key) or MapSet.member?(state.inflight_ids, key) ->
        {:reply, :ok, state}

      load >= capacity ->
        Logger.warning("virus scan queue full",
          queued: :queue.len(state.queue),
          inflight: map_size(state.inflight),
          max_queue: max_queue,
          max_concurrency: max_concurrency
        )

        {:reply, {:error, :queue_full}, state}

      true ->
        state = %{
          state
          | queue: :queue.in(key, state.queue),
            queued: MapSet.put(state.queued, key)
        }

        {:reply, :ok, drain(state)}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {max_concurrency, max_queue} = limits(state)

    {:reply,
     %{
       queued: :queue.len(state.queue),
       inflight: map_size(state.inflight),
       max_concurrency: max_concurrency,
       max_queue: max_queue
     }, state}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_map_key(state.inflight, ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish_job(state, ref)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    if Map.has_key?(state.inflight, ref) do
      {:noreply, finish_job(state, ref)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp finish_job(state, ref) do
    {key, inflight} = Map.pop!(state.inflight, ref)

    state = %{
      state
      | inflight: inflight,
        inflight_ids: MapSet.delete(state.inflight_ids, key)
    }

    drain(state)
  end

  defp drain(state) do
    {max_concurrency, _max_queue} = limits(state)

    if map_size(state.inflight) >= max_concurrency do
      state
    else
      case :queue.out(state.queue) do
        {:empty, _queue} ->
          state

        {{:value, {prefix, upload_id} = key}, queue} ->
          task =
            Task.Supervisor.async_nolink(Messngr.TaskSupervisor, fn ->
              Messngr.Media.VirusScan.scan_upload(prefix, upload_id)
            end)

          state = %{
            state
            | queue: queue,
              queued: MapSet.delete(state.queued, key),
              inflight: Map.put(state.inflight, task.ref, key),
              inflight_ids: MapSet.put(state.inflight_ids, key)
          }

          drain(state)
      end
    end
  end

  defp limits(state) do
    config = Application.get_env(:msgr, Messngr.Media.VirusScan, [])

    max_concurrency =
      state.max_concurrency ||
        Keyword.get(config, :max_concurrency, @default_max_concurrency)

    max_queue =
      state.max_queue ||
        Keyword.get(config, :max_queue, @default_max_queue)

    {max(1, max_concurrency), max(0, max_queue)}
  end
end
