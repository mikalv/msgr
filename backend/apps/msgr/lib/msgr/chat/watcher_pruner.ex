defmodule Messngr.Chat.WatcherPruner do
  @moduledoc """
  Periodically sweeps conversation watchers to remove idle records left behind
  when clients disconnect without sending an `unwatch` command.
  """

  use GenServer
  require Logger

  alias Messngr.Chat

  @default_interval :timer.minutes(1)

  @type option ::
          {:interval, non_neg_integer()}
          | {:interval_ms, non_neg_integer()}
          | {:enabled, boolean()}
          | {:name, atom()}

  @doc false
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Builds a child specification for supervisors. Returns `nil` when the pruner
  is disabled.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec() | nil
  def child_spec(opts) do
    case Keyword.get(opts, :enabled, true) do
      true ->
        name = Keyword.get(opts, :name, __MODULE__)
        interval = normalize_interval(opts)

        Supervisor.child_spec({__MODULE__, [name: name, interval: interval]}, id: name)

      _ ->
        nil
    end
  end

  @doc """
  Triggers an immediate sweep on the given server (defaults to the globally
  registered pruner).
  """
  @spec sweep_now(GenServer.server()) :: :ok
  def sweep_now(server \\ __MODULE__) do
    GenServer.cast(server, :sweep_now)
  end

  @impl true
  def init(opts) do
    interval = normalize_interval(opts)
    state = %{interval: interval}

    send(self(), :sweep)

    {:ok, state}
  end

  @impl true
  def handle_info(:sweep, %{interval: interval} = state) do
    run_sweep()
    schedule_next(interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:sweep_now, state) do
    run_sweep()
    {:noreply, state}
  end

  defp normalize_interval(opts) do
    opts
    |> Keyword.get(:interval_ms)
    |> Kernel.||(Keyword.get(opts, :interval))
    |> Kernel.||(@default_interval)
    |> max(:timer.seconds(5))
  end

  defp schedule_next(interval) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :sweep, interval)
  end

  defp run_sweep do
    case Chat.purge_stale_watchers() do
      {:ok, %{conversations: 0}} ->
        :ok

      {:ok, %{conversations: conversations, watchers: watchers}} ->
        Logger.debug("conversation watcher sweep", conversations: conversations, watchers: watchers)
        :ok
    end
  end
end
