defmodule Messngr.Noise.DevHandshake do
  @moduledoc """
  Utility helpers for issuing development Noise handshake sessions without
  running the full transport daemon. The intent is to unblock local/mobile
  clients while the real socket-based transport is being brought online.

  The generated sessions are persisted in the Noise registry so follow-up OTP
  verification can attach account metadata in exactly the same way as a
  full handshake would do.
  """

  alias Messngr.Noise.{Handshake, KeyLoader}
  alias Messngr.Transport.Noise.Session
  alias UUID

  @default_ttl_ms :timer.minutes(5)
  @config_key __MODULE__

  @doc """
  Generates and persists a Noise session that mimics the result of a completed
  NX handshake. Returns a map with the session metadata needed by clients to
  finish OTP verification.

  Options:

    * `:ttl_ms` – overrides the derived TTL for the registry entry.
  """
  @spec generate(keyword()) ::
          {:ok,
           %{
             session: Session.t(),
             signature: String.t(),
             device_key: String.t(),
             device_private_key: String.t(),
             expires_at: DateTime.t(),
             server: map()
           }}
          | {:error, term()}
  def generate(opts \\ []) do
    with :ok <- ensure_enabled(),
         {:ok, noise_config} <- fetch_noise_config(),
         {:ok, registry} <- ensure_registry_started(),
         {:ok, session_data} <- build_session(noise_config, opts),
         {:ok, session} <- Handshake.persist(session_data.session, registry: registry) do
      signature = Handshake.encoded_signature(session)
      device_key = Handshake.device_key(session)

      response = %{
        session: session,
        signature: signature,
        device_key: device_key,
        device_private_key: session_data.device_private_key,
        expires_at: session_data.expires_at,
        server: session_data.server
      }

      {:ok, response}
    end
  end

  def enabled? do
    config() |> Keyword.get(:enabled, false)
  end

  defp ensure_enabled do
    if enabled?() do
      :ok
    else
      {:error, :dev_handshake_disabled}
    end
  end

  defp fetch_noise_config do
    noise_config = Application.get_env(:msgr, :noise, [])
    handshake_config = config()

    cond do
      Keyword.get(noise_config, :enabled, false) ->
        ensure_key_material(noise_config)

      allow_without_transport?(handshake_config) ->
        ensure_key_material(noise_config)

      true ->
        {:error, :noise_transport_disabled}
    end
  end

  defp ensure_registry_started do
    case Process.whereis(Messngr.Transport.Noise.Registry) do
      nil ->
        opts =
          Application.get_env(:msgr, :noise_session_registry, [])
          |> Keyword.put_new(:ttl, @default_ttl_ms)

        case Messngr.Transport.Noise.Registry.start_link(opts) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, {:registry_start_failed, reason}}
        end

      pid ->
        {:ok, pid}
    end
  end

  defp build_session(noise_config, opts) do
    _server_private = Keyword.fetch!(noise_config, :private_key)
    prologue = Keyword.get(noise_config, :prologue, KeyLoader.prologue())
    protocol = Keyword.get(noise_config, :protocol, KeyLoader.protocol())
    fingerprint = Keyword.get(noise_config, :fingerprint)

    device_private = :crypto.strong_rand_bytes(32)
    device_public = KeyLoader.public_key(device_private)
    handshake_hash = :crypto.strong_rand_bytes(32)
    token = :crypto.strong_rand_bytes(32)

    ttl_ms = Keyword.get(opts, :ttl_ms, registry_ttl())
    expires_at = DateTime.add(DateTime.utc_now(), div(ttl_ms, 1000), :second)

    session =
      Session.established_session(
        id: UUID.uuid4(),
        actor: %{account_id: "bootstrap", profile_id: "bootstrap"},
        token: token,
        token_bytes: byte_size(token),
        token_generator: &:crypto.strong_rand_bytes/1,
        handshake_hash: handshake_hash,
        remote_static: device_public,
        prologue: prologue,
        metadata: %{}
      )

    {:ok,
     %{
       session: session,
       device_private_key: Base.url_encode64(device_private, padding: false),
       expires_at: expires_at,
       server: %{
         protocol: protocol,
         prologue: prologue,
         fingerprint: fingerprint,
         public_key:
           noise_config
           |> Keyword.fetch!(:public_key)
           |> Base.encode64()
       }
     }}
  end

  defp registry_ttl do
    Application.get_env(:msgr, :noise_session_registry, [])
    |> Keyword.get(:ttl, @default_ttl_ms)
  end

  defp config do
    Application.get_env(:msgr, @config_key, [])
  end

  defp allow_without_transport?(config) do
    Keyword.get(config, :allow_without_transport, false)
  end

  defp ensure_key_material(noise_config) do
    with {:ok, private_key} <- resolve_private_key(noise_config),
         {:ok, public_key} <- resolve_public_key(noise_config, private_key) do
      fingerprint =
        Keyword.get(noise_config, :fingerprint) ||
          KeyLoader.fingerprint(private_key)

      protocol = Keyword.get(noise_config, :protocol, KeyLoader.protocol())
      prologue = Keyword.get(noise_config, :prologue, KeyLoader.prologue())

      {:ok,
       noise_config
       |> Keyword.put(:private_key, private_key)
       |> Keyword.put(:public_key, public_key)
       |> Keyword.put(:fingerprint, fingerprint)
       |> Keyword.put(:protocol, protocol)
       |> Keyword.put(:prologue, prologue)}
    end
  end

  defp resolve_private_key(config) do
    case Keyword.get(config, :private_key) do
      key when is_binary(key) and byte_size(key) == 32 ->
        {:ok, key}

      key when is_binary(key) ->
        decode_base64_key(key, :noise_private_key_invalid)

      _ ->
        config
        |> Keyword.get(:private_key_base64)
        |> decode_base64_key(:noise_private_key_invalid)
        |> case do
          {:ok, key} -> {:ok, key}
          {:error, :not_found} -> load_private_key(config)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp resolve_public_key(config, private_key) do
    case Keyword.get(config, :public_key) do
      key when is_binary(key) and byte_size(key) == 32 ->
        {:ok, key}

      key when is_binary(key) ->
        decode_base64_key(key, :noise_public_key_invalid)

      _ ->
        config
        |> Keyword.get(:public_key_base64)
        |> decode_base64_key(:noise_public_key_invalid)
        |> case do
          {:ok, key} -> {:ok, key}
          {:error, :not_found} -> {:ok, KeyLoader.public_key(private_key)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp load_private_key(config) do
    config
    |> key_loader_opts()
    |> KeyLoader.load()
    |> case do
      {:ok, key} -> {:ok, key}
      {:error, :noise_static_key_not_found} -> {:error, :noise_private_key_missing}
      {:error, reason} -> {:error, {:noise_private_key_load_failed, reason}}
    end
  end

  defp key_loader_opts(config) do
    []
    |> maybe_put(:env_var, Keyword.get(config, :env_var))
    |> maybe_put(:secret_id, Keyword.get(config, :secret_id))
    |> maybe_put(:secret_field, Keyword.get(config, :secret_field))
    |> maybe_put(:secret_region, Keyword.get(config, :secret_region))
    |> maybe_put(:default, Keyword.get(config, :default_static_key))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp decode_base64_key(nil, _error), do: {:error, :not_found}

  defp decode_base64_key(value, error) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, decoded} when byte_size(decoded) == 32 -> {:ok, decoded}
      _ -> {:error, error}
    end
  end

  defp decode_base64_key(_value, error), do: {:error, error}
end
