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
    with {:ok, noise_config} <- fetch_noise_config(),
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

  defp fetch_noise_config do
    noise_config = Application.get_env(:msgr, :noise, [])

    cond do
      Keyword.get(noise_config, :enabled, false) == false ->
        {:error, :noise_transport_disabled}

      Keyword.get(noise_config, :private_key) in [nil, ""] ->
        {:error, :noise_private_key_missing}

      Keyword.get(noise_config, :public_key) in [nil, ""] ->
        {:error, :noise_public_key_missing}

      true ->
        {:ok, noise_config}
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
end
