defmodule Messngr.Bridges.Auth.CredentialVault do
  @moduledoc """
  Minimal in-memory credential vault used during development and testing.

  Bridge OAuth tokens are stored under opaque references so the Msgr client and
  other subsystems can refer to them without direct access. Real deployments
  should replace this with a persistent secrets manager integration.
  """

  @table :bridge_auth_credential_vault

  @spec store_tokens(String.t() | atom(), String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def store_tokens(service, session_id, tokens, opts \\ [])
  def store_tokens(service, session_id, tokens, opts)
      when is_map(tokens) and (is_binary(service) or is_atom(service)) and is_binary(session_id) do
    ensure_table!()

    ref = Keyword.get_lazy(opts, :ref, &generate_ref/0)

    record = %{
      "service" => to_string(service),
      "session_id" => session_id,
      "tokens" => tokens,
      "inserted_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    }

    true = :ets.insert(@table, {ref, record})

    {:ok, ref}
  end

  def store_tokens(_service, _session_id, _tokens, _opts), do: {:error, :invalid_payload}

  @spec fetch(String.t()) :: {:ok, map()} | {:error, term()}
  def fetch(ref) when is_binary(ref) do
    ensure_table!()

    case :ets.lookup(@table, ref) do
      [{^ref, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  def fetch(_ref), do: {:error, :not_found}

  @spec delete(String.t()) :: :ok
  def delete(ref) when is_binary(ref) do
    ensure_table!()
    :ets.delete(@table, ref)
    :ok
  end

  def delete(_ref), do: :ok

  defp generate_ref do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:set, :protected, :named_table, read_concurrency: true])
      _ -> :ok
    end
  end
end
