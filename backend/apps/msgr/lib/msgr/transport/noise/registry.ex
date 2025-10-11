defmodule Messngr.Transport.Noise.Registry do
  @moduledoc """
  In-memory store for live Noise sessions. The registry keeps both the session
  identifier and the short-lived session token produced by
  `Messngr.Transport.Noise.Session` so follow-up API calls can be resolved to the
  appropriate handshake state.

  Sessions automatically expire after a configurable TTL and a periodic cleanup
  ensures stale entries are pruned without caller intervention.
  """

  use GenServer

  alias Messngr.Transport.Noise.Session

  @type id :: String.t()
  @type token :: binary()

  @default_ttl :timer.minutes(5)

  @doc """
  Starts the registry process.

  Options:
    * `:ttl` - expiration in milliseconds (default: 5 minutes)
    * `:cleanup_interval` - interval for pruning expired sessions (defaults to half the TTL)
    * `:name` - registered name
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, max(div(ttl, 2), 1))
    name = Keyword.get(opts, :name, __MODULE__)

    if ttl <= 0 do
      raise ArgumentError, ":ttl must be a positive integer"
    end

    GenServer.start_link(__MODULE__, %{ttl: ttl, cleanup_interval: cleanup_interval}, name: name)
  end

  @doc """
  Stores or refreshes a session entry. Updating the registry also refreshes the
  expiration for the session.
  """
  @spec put(GenServer.server(), Session.t()) :: {:ok, Session.t()}
  def put(server \\ __MODULE__, %Session{} = session) do
    GenServer.call(server, {:put, session})
  end

  @doc """
  Fetches a session by its identifier.
  """
  @spec fetch(GenServer.server(), id()) :: {:ok, Session.t()} | :error
  def fetch(server \\ __MODULE__, id) when is_binary(id) do
    GenServer.call(server, {:fetch, {:id, id}})
  end

  @doc """
  Fetches a session by the negotiated session token.
  """
  @spec fetch_by_token(GenServer.server(), token()) :: {:ok, Session.t()} | :error
  def fetch_by_token(server \\ __MODULE__, token) when is_binary(token) do
    GenServer.call(server, {:fetch, {:token, token}})
  end

  @doc """
  Extends the TTL for a given session identifier.
  """
  @spec touch(GenServer.server(), id()) :: :ok | :error
  def touch(server \\ __MODULE__, id) when is_binary(id) do
    GenServer.call(server, {:touch, {:id, id}})
  end

  @doc """
  Extends the TTL using the session token as lookup key.
  """
  @spec touch_by_token(GenServer.server(), token()) :: :ok | :error
  def touch_by_token(server \\ __MODULE__, token) when is_binary(token) do
    GenServer.call(server, {:touch, {:token, token}})
  end

  @doc """
  Deletes a session using its identifier.
  """
  @spec delete(GenServer.server(), id()) :: :ok | :error
  def delete(server \\ __MODULE__, id) when is_binary(id) do
    GenServer.call(server, {:delete, {:id, id}})
  end

  @doc """
  Deletes a session using its token.
  """
  @spec delete_by_token(GenServer.server(), token()) :: :ok | :error
  def delete_by_token(server \\ __MODULE__, token) when is_binary(token) do
    GenServer.call(server, {:delete, {:token, token}})
  end

  @doc """
  Returns the number of live sessions.
  """
  @spec count(GenServer.server()) :: non_neg_integer()
  def count(server \\ __MODULE__) do
    GenServer.call(server, :count)
  end

  @doc """
  Returns all sessions currently tracked by the registry.
  """
  @spec all(GenServer.server()) :: [Session.t()]
  def all(server \\ __MODULE__) do
    GenServer.call(server, :all)
  end

  @impl GenServer
  def init(%{ttl: ttl, cleanup_interval: cleanup_interval}) do
    state = %{
      ttl: ttl,
      cleanup_interval: cleanup_interval,
      sessions: %{},
      tokens: %{}
    }

    schedule_cleanup(cleanup_interval)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:put, %Session{} = session}, _from, state) do
    now = now_ms()
    state = drop_expired(state, now)
    state = put_session(state, session, now + state.ttl)
    {:reply, {:ok, session}, state}
  end

  def handle_call({:fetch, key}, _from, state) do
    now = now_ms()
    state = drop_expired(state, now)

    case locate_entry(state, key) do
      {:ok, id, %{session: session} = entry} ->
        {:reply, {:ok, session}, %{state | sessions: Map.put(state.sessions, id, entry)}}

      :error ->
        {:reply, :error, state}
    end
  end

  def handle_call({:touch, key}, _from, state) do
    now = now_ms()
    state = drop_expired(state, now)

    case locate_entry(state, key) do
      {:ok, id, entry} ->
        updated = %{entry | expires_at: now + state.ttl}
        {:reply, :ok, %{state | sessions: Map.put(state.sessions, id, updated)}}

      :error ->
        {:reply, :error, state}
    end
  end

  def handle_call({:delete, key}, _from, state) do
    case remove_entry(state, key) do
      {:ok, state} -> {:reply, :ok, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call(:count, _from, state) do
    now = now_ms()
    state = drop_expired(state, now)
    {:reply, map_size(state.sessions), state}
  end

  def handle_call(:all, _from, state) do
    now = now_ms()
    state = drop_expired(state, now)
    sessions = Enum.map(state.sessions, fn {_id, %{session: session}} -> session end)
    {:reply, sessions, state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    now = now_ms()
    state = drop_expired(state, now)
    schedule_cleanup(state.cleanup_interval)
    {:noreply, state}
  end

  defp put_session(%{sessions: sessions, tokens: tokens} = state, %Session{id: id, token: token} = session, expires_at) do
    {sessions, tokens} = maybe_evict_existing(session, sessions, tokens)

    tokens =
      case token do
        nil -> tokens
        token -> Map.put(tokens, token, id)
      end

    sessions = Map.put(sessions, id, %{session: session, expires_at: expires_at})
    %{state | sessions: sessions, tokens: tokens}
  end

  defp maybe_evict_existing(%Session{id: id}, sessions, tokens) do
    case Map.get(sessions, id) do
      nil -> {sessions, tokens}
      %{session: %Session{token: old_token}} ->
        tokens = if old_token, do: Map.delete(tokens, old_token), else: tokens
        {Map.delete(sessions, id), tokens}
    end
  end

  defp drop_expired(%{sessions: sessions, tokens: tokens} = state, now) do
    {sessions, tokens} =
      Enum.reduce(sessions, {sessions, tokens}, fn {id, %{expires_at: expires_at, session: session}}, {acc_sessions, acc_tokens} ->
        if expires_at <= now do
          token = session.token
          acc_tokens = if token, do: Map.delete(acc_tokens, token), else: acc_tokens
          {Map.delete(acc_sessions, id), acc_tokens}
        else
          {acc_sessions, acc_tokens}
        end
      end)

    %{state | sessions: sessions, tokens: tokens}
  end

  defp locate_entry(%{sessions: sessions}, {:id, id}) do
    case Map.fetch(sessions, id) do
      {:ok, entry} -> {:ok, id, entry}
      :error -> :error
    end
  end

  defp locate_entry(%{sessions: sessions, tokens: tokens}, {:token, token}) do
    with {:ok, id} <- Map.fetch(tokens, token),
         {:ok, entry} <- Map.fetch(sessions, id) do
      {:ok, id, entry}
    else
      _ -> :error
    end
  end

  defp remove_entry(%{sessions: sessions, tokens: tokens} = state, {:id, id}) do
    case Map.pop(sessions, id) do
      {nil, _} -> :error
      {%{session: session}, sessions} ->
        tokens = maybe_drop_token(tokens, session.token)
        {:ok, %{state | sessions: sessions, tokens: tokens}}
    end
  end

  defp remove_entry(%{tokens: tokens} = state, {:token, token}) do
    case Map.pop(tokens, token) do
      {nil, _} -> :error
      {id, tokens} -> remove_entry(%{state | tokens: tokens}, {:id, id})
    end
  end

  defp maybe_drop_token(tokens, nil), do: tokens
  defp maybe_drop_token(tokens, token), do: Map.delete(tokens, token)

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp now_ms do
    System.monotonic_time(:millisecond)
  end
end
