defmodule Messngr.Noise.Handshake do
  @moduledoc """
  Helper utilities for binding Noise handshake sessions to OTP/OIDC flows.

  The helpers expose a deterministic attestation signature derived from the
  handshake hash and session token, ensuring that follow-up API calls can prove
  they completed the Noise handshake with the backend. They also provide
  convenience wrappers around the registry and session store so callers can
  persist handshakes before account/profile metadata is known and later attach
  the authenticated actor once OTP verification succeeds.
  """

  alias Messngr.Noise.SessionStore
  alias Messngr.Transport.Noise.{Registry, Session}
  alias Plug.Crypto

  @signature_hash :sha256

  @doc """
  Persists the handshake session in the registry so it can be resolved by id.
  """
  @spec persist(Session.t(), keyword()) :: {:ok, Session.t()}
  def persist(%Session{} = session, opts \\ []) do
    registry = Keyword.get(opts, :registry, Registry)
    Registry.put(registry, session)
  end

  @doc """
  Fetches a handshake session by id from the registry.
  """
  @spec fetch(String.t(), keyword()) :: {:ok, Session.t()} | :error
  def fetch(session_id, opts \\ []) when is_binary(session_id) do
    registry = Keyword.get(opts, :registry, Registry)
    Registry.fetch(registry, session_id)
  end

  @doc """
  Generates the binary attestation signature for the given handshake session.
  """
  @spec signature(Session.t()) :: binary()
  def signature(%Session{} = session) do
    hash = Session.handshake_hash(session)
    token = Session.token(session)

    cond do
      not is_binary(hash) -> raise ArgumentError, "Noise handshake hash not available"
      not is_binary(token) -> raise ArgumentError, "Noise session token not available"
      true -> :crypto.mac(:hmac, @signature_hash, token, hash)
    end
  end

  @doc """
  Returns the attestation signature encoded as URL-safe base64.
  """
  @spec encoded_signature(Session.t()) :: String.t()
  def encoded_signature(%Session{} = session) do
    session
    |> signature()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Attempts to decode a client-provided attestation signature.
  """
  @spec decode_signature(String.t()) :: {:ok, binary()} | :error
  def decode_signature(value) when is_binary(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> Base.decode64(value)
    end
  end

  @doc """
  Verifies that the provided signature matches the expected attestation value
  for the handshake session.
  """
  @spec verify_signature(Session.t(), binary()) :: :ok | {:error, :invalid_signature}
  def verify_signature(%Session{} = session, signature) when is_binary(signature) do
    expected = signature(session)

    if Crypto.secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def verify_signature(_session, _signature), do: {:error, :invalid_signature}

  @doc """
  Returns the client's static public key as a URL-safe base64 string.
  """
  @spec device_key(Session.t()) :: String.t()
  def device_key(%Session{} = session) do
    session
    |> Session.remote_static()
    |> case do
      nil -> raise ArgumentError, "Noise remote static key not available"
      value -> Base.url_encode64(value, padding: false)
    end
  end

  @doc """
  Attaches actor metadata to the handshake session, persists it in the registry
  and returns the encoded session token.
  """
  @spec finalize(Session.t(), Session.actor() | map(), keyword()) ::
          {:ok, %{session: Session.t(), token: String.t()}}
  def finalize(%Session{} = session, actor, opts \\ []) do
    with {:ok, session} <- SessionStore.register(session, actor, opts) do
      token =
        session
        |> Session.token()
        |> SessionStore.encode_token()

      {:ok, %{session: session, token: token}}
    end
  end
end
