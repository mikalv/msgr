defmodule Messngr.Bridges.Auth.CredentialInbox do
  @moduledoc """
  Ephemeral in-memory storage for bridge credential submissions.

  Non-OAuth credential payloads are dropped into this inbox so bridge daemons
  can retrieve them over their queue transport. Payloads expire automatically
  after a configurable TTL to avoid retaining secrets longer than necessary.
  """

  @table :bridge_auth_credential_inbox
  @default_ttl 300

  @spec put(String.t(), map(), keyword()) :: :ok | {:error, term()}
  def put(session_id, payload, opts \\ []) when is_binary(session_id) and is_map(payload) do
    ensure_table!()

    ttl = Keyword.get(opts, :ttl, @default_ttl)
    ttl = max(ttl, 1)

    expires_at = System.monotonic_time() + System.convert_time_unit(ttl, :second, :native)

    true = :ets.insert(@table, {session_id, payload, expires_at})
    :ok
  end

  def put(_session_id, _payload, _opts), do: {:error, :invalid_payload}

  @spec checkout(String.t()) :: {:ok, map()} | {:error, term()}
  def checkout(session_id) when is_binary(session_id) do
    ensure_table!()

    case :ets.take(@table, session_id) do
      [{^session_id, payload, expires_at}] ->
        if expired?(expires_at) do
          {:error, :expired}
        else
          {:ok, payload}
        end

      [] ->
        {:error, :not_found}
    end
  end

  def checkout(_session_id), do: {:error, :not_found}

  @spec cleanup_expired() :: non_neg_integer()
  def cleanup_expired do
    ensure_table!()

    now = System.monotonic_time()

    :ets.foldl(
      fn {session_id, _payload, expires_at}, acc ->
        if expires_at < now do
          :ets.delete(@table, session_id)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table
    )
  end

  defp expired?(expires_at), do: expires_at < System.monotonic_time()

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:set, :protected, :named_table, read_concurrency: true])
      _ -> :ok
    end
  end
end
