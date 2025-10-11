defmodule Messngr.Noise.KeyLoader do
  @moduledoc """
  Helper for loading and representing the static Noise key material used by the
  backend.

  The loader supports three strategies, evaluated in the following order:

    1. Directly from an environment variable (base64-encoded private key).
    2. Via a Secrets Manager implementation.
    3. Falling back to a default provided through configuration (dev/test).

  All helpers return the binary private key which can then be used to derive the
  public key and fingerprint.
  """

  require Logger

  @default_env_var "NOISE_STATIC_KEY"
  @default_secret_manager Messngr.Secrets.Aws
  @protocol "Noise_NX_25519_ChaChaPoly_Blake2b"
  @prologue "msgr-noise/v1"
  @private_key_bytes 32

  @type origin :: {:env, String.t()} | {:secret, String.t()} | :default

  @doc """
  Attempts to load the private key using the configured strategies.

  Options:

    * `:env_var` - overrides which environment variable to read from.
    * `:secret_id` - id/name in the secrets manager.
    * `:secret_field` - optional JSON field inside the secret payload.
    * `:default` - fallback base64-encoded key (typically configured in dev).
    * `:secrets_manager` - module implementing `Messngr.Secrets.Manager`.

  Returns `{:ok, key}` on success or `{:error, reason}`.
  """
  @spec load(Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def load(opts \\ []) do
    env_var = Keyword.get(opts, :env_var, @default_env_var)
    secret_id = Keyword.get(opts, :secret_id, System.get_env("NOISE_STATIC_KEY_SECRET_ID"))
    secret_field = Keyword.get(opts, :secret_field, System.get_env("NOISE_STATIC_KEY_SECRET_FIELD"))
    default = Keyword.get(opts, :default)
    secret_region = Keyword.get(opts, :secret_region, System.get_env("NOISE_STATIC_KEY_SECRET_REGION"))
    secret_opts = maybe_put_region(opts, secret_region)

    with {:error, _} <- fetch_from_env(env_var, opts),
         {:error, _} <- fetch_from_secret(secret_id, secret_field, secret_opts),
         {:error, _} <- fetch_from_default(default) do
      {:error, :noise_static_key_not_found}
    end
  end

  @doc """
  Same as `load/1` but raises on failure.
  """
  @spec load!(Keyword.t()) :: binary()
  def load!(opts \\ []) do
    case load(opts) do
      {:ok, key} -> key
      {:error, reason} -> raise ArgumentError, "Unable to load Noise static key: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the Noise protocol identifier used by msgr.
  """
  def protocol, do: @protocol

  @doc """
  Returns the prologue constant that must be supplied to the Noise handshake.
  """
  def prologue, do: @prologue

  @doc """
  Derives the Curve25519 public key from the static private key.
  """
  @spec public_key(binary()) :: binary()
  def public_key(private_key) when is_binary(private_key) do
    validate_size!(private_key)
    :enacl.crypto_scalarmult_base(private_key)
  end

  @doc """
  Calculates a BLAKE2b-256 fingerprint from the public key.
  """
  @spec fingerprint(binary()) :: String.t()
  def fingerprint(private_key) when is_binary(private_key) do
    private_key
    |> public_key()
    |> then(&:crypto.hash(:blake2b, 32, &1))
    |> Base.encode16(case: :lower)
  end

  defp fetch_from_env(nil, _opts), do: {:error, :env_var_not_configured}

  defp fetch_from_env(env_var, _opts) do
    case System.get_env(env_var) do
      nil -> {:error, {:env_var_missing, env_var}}
      value -> decode_key(value, {:env, env_var})
    end
  end

  defp fetch_from_secret(nil, _field, _opts), do: {:error, :secret_not_configured}

  defp fetch_from_secret(secret_id, secret_field, opts) do
    manager =
      Keyword.get_lazy(opts, :secrets_manager, fn ->
        Application.get_env(:msgr, :secrets_manager, @default_secret_manager)
      end)

    case manager && manager.fetch(secret_id, opts) do
      {:ok, %{"SecretString" => secret}} ->
        decode_key(extract_secret(secret, secret_field, secret_id), {:secret, secret_id})

      {:ok, %{"SecretBinary" => secret}} ->
        decode_key(secret, {:secret, secret_id})

      {:ok, secret} when is_binary(secret) ->
        decode_key(extract_secret(secret, secret_field, secret_id), {:secret, secret_id})

      {:error, reason} ->
        Logger.warning("Unable to fetch Noise key from secrets manager", reason: inspect(reason))
        {:error, {:secret_manager_error, reason}}

      nil ->
        {:error, :secret_manager_not_available}
    end
  end

  defp fetch_from_default(nil), do: {:error, :no_default_key}

  defp fetch_from_default(value) when is_binary(value) do
    decode_key(value, :default)
  end

  defp fetch_from_default({:base64, value}) when is_binary(value) do
    decode_key(value, :default)
  end

  defp fetch_from_default(fun) when is_function(fun, 0) do
    fun.()
    |> fetch_from_default()
  end

  defp fetch_from_default({:ok, value}) do
    fetch_from_default(value)
  end

  defp fetch_from_default({:error, _} = error), do: error

  defp fetch_from_default(_other), do: {:error, :invalid_default_config}

  defp extract_secret(secret_string, nil, _secret_id), do: secret_string

  defp extract_secret(secret_string, field, secret_id) do
    with {:ok, decoded} <- Jason.decode(secret_string),
         value when is_binary(value) <- Map.get(decoded, field) do
      value
    else
      {:error, reason} ->
        Logger.error("Failed to decode JSON secret for Noise key", reason: inspect(reason), secret_id: secret_id)
        raise ArgumentError, "Secrets Manager payload is not valid JSON"

      nil ->
        raise ArgumentError, "Secrets Manager payload missing field '#{field}'"
    end
  end

  defp decode_key(value, origin) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, private_key} ->
        ensure_length(private_key, origin)

      :error ->
        ensure_length(value, origin)
    end
  end

  defp ensure_length(private_key, origin) do
    case byte_size(private_key) do
      @private_key_bytes -> {:ok, private_key}
      other ->
        Logger.error("Noise static key has invalid length", length: other, origin: inspect(origin))
        {:error, {:invalid_length, origin, other}}
    end
  end

  defp validate_size!(private_key) do
    if byte_size(private_key) != @private_key_bytes do
      raise ArgumentError, "Noise private key must be #{@private_key_bytes} bytes"
    end
  end

  defp maybe_put_region(opts, region) when region in [nil, ""], do: opts
  defp maybe_put_region(opts, region), do: Keyword.put(opts, :region, region)
end
