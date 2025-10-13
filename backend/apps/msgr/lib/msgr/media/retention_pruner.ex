defmodule Messngr.Media.RetentionPruner do
  @moduledoc """
  Periodically prunes expired media uploads and their backing storage objects.
  """

  use GenServer
  require Logger

  alias Messngr.Media

  @default_interval :timer.minutes(10)
  @default_batch_size 100

  @type option :: {:interval, non_neg_integer()} | {:batch_size, pos_integer()} | {:name, atom()}

  @doc false
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Builds a child specification when the pruner is enabled. Returns `nil` when
  the provided options include `enabled: false` so supervision trees can skip
  starting the process entirely.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec() | nil
  def child_spec(opts) do
    case Keyword.get(opts, :enabled, true) do
      true ->
        name = Keyword.get(opts, :name, __MODULE__)
        interval = Keyword.get(opts, :interval_ms, Keyword.get(opts, :interval, @default_interval))
        batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

        Supervisor.child_spec({__MODULE__, [name: name, interval: interval, batch_size: batch_size]},
          id: name
        )

      _ ->
        nil
    end
  end

  @doc """
  Triggers an immediate prune run on the given server (defaults to the globally
  registered pruner).
  """
  @spec prune_now(GenServer.server()) :: :ok
  def prune_now(server \\ __MODULE__) do
    GenServer.cast(server, :prune_now)
  end

  @impl true
  def init(opts) do
    interval = normalize_interval(opts)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    state = %{interval: interval, batch_size: batch_size}

    send(self(), :prune)

    {:ok, state}
  end

  @impl true
  def handle_info(:prune, state) do
    run_prune(state.batch_size)
    schedule_next(state.interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:prune_now, state) do
    run_prune(state.batch_size)
    {:noreply, state}
  end

  defp normalize_interval(opts) do
    interval =
      opts
      |> Keyword.get(:interval_ms)
      |> Kernel.||(Keyword.get(opts, :interval))
      |> Kernel.||(@default_interval)

    max(interval, :timer.seconds(30))
  end

  defp schedule_next(interval) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :prune, interval)
  end

  defp run_prune(batch_size) do
    %{scanned: scanned, deleted: deleted, errors: errors} = Media.prune_expired_uploads(limit: batch_size)

    Logger.debug("media retention prune run", scanned: scanned, deleted: deleted, errors: length(errors))

    Enum.each(errors, fn %{id: id, reason: reason} ->
      Logger.warning("media retention prune failed", upload_id: id, reason: inspect(reason))
    end)
  end
end
