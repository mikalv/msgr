defmodule Messngr.Transport.Noise.Session do
  @moduledoc """
  Wrapper around the `:enoise` handshake state that powers the Noise transport
  used by msgr. The session tracks the handshake lifecycle, negotiated cipher
  states and a short-lived session token that can be registered in the
  `Messngr.Transport.Noise.Registry`.

  The server exposes two entrypoints: `new_device/1` for onboarding fresh
  devices (Noise NX) and `known_device/1` for clients with a pre-provisioned
  static key. Known devices will optimistically attempt an IK handshake before
  falling back to XX if the stored static key no longer matches the client.

  Once the handshake completes the session can encrypt/decrypt payloads with
  the derived cipher states and supports explicit re-keying.
  """

  alias Messngr.Noise.KeyLoader
  alias UUID

  @typedoc "Supported Noise handshake patterns"
  @type pattern :: :nx | :ik | :xx

  @typedoc "Session status"
  @type status :: :handshaking | :established | {:error, term()}

  @typedoc "Metadata describing the authenticated actor bound to the session"
  @type actor :: %{
          required(:account_id) => String.t(),
          required(:profile_id) => String.t(),
          optional(:device_id) => String.t(),
          optional(:device_public_key) => String.t()
        }

  @typedoc "Noise role"
  @type role :: :initiator | :responder

  @protocols %{
    nx: "Noise_NX_25519_ChaChaPoly_Blake2b",
    ik: "Noise_IK_25519_ChaChaPoly_Blake2b",
    xx: "Noise_XX_25519_ChaChaPoly_Blake2b"
  }

  @default_token_bytes 32

  defstruct [
    :id,
    :role,
    :status,
    :current_pattern,
    :handshake_state,
    :tx,
    :rx,
    :handshake_hash,
    :remote_static,
    :server_keypair,
    :prologue,
    :token,
    :token_bytes,
    :token_generator,
    :ephemeral_override,
    :remote_static_hint,
    :started_at,
    pending_patterns: [],
    actor: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          role: role(),
          status: status(),
          current_pattern: pattern() | nil,
          handshake_state: term() | nil,
          tx: term() | nil,
          rx: term() | nil,
          handshake_hash: binary() | nil,
          remote_static: binary() | nil,
          server_keypair: term(),
          prologue: binary(),
          token: binary() | nil,
          token_bytes: pos_integer(),
          token_generator: (pos_integer() -> binary()),
          pending_patterns: [pattern()],
          ephemeral_override: term(),
          remote_static_hint: binary() | nil,
          started_at: integer() | nil,
          actor: actor() | nil
        }

  @doc """
  Creates a session for onboarding new devices. The server only needs its
  static key and optionally a prologue override.
  """
  @spec new_device(Keyword.t()) :: t()
  def new_device(opts \\ []) do
    init_session([:nx], opts)
  end

  @doc """
  Creates a session for a known device. The `:remote_static` option must be the
  client's previously stored public key. The session will attempt an IK
  handshake before falling back to XX if the client rotated its key.
  """
  @spec known_device(Keyword.t()) :: t()
  def known_device(opts) do
    remote_static = Keyword.get(opts, :remote_static)

    if not is_binary(remote_static) do
      raise ArgumentError, ":remote_static must be a 32-byte binary public key"
    end

    init_session([:ik, :xx], opts)
  end

  @doc """
  Returns `true` when the handshake completed and cipher states are ready.
  """
  @spec established?(t()) :: boolean()
  def established?(%__MODULE__{status: :established}), do: true
  def established?(_session), do: false

  @doc """
  The direction expected for the next handshake step.
  """
  @spec expecting(t()) :: :in | :out | :done
  def expecting(%__MODULE__{handshake_state: nil}), do: :done
  def expecting(%__MODULE__{handshake_state: state}), do: :enoise_hs_state.next_message(state)

  @doc """
  Processes an inbound handshake message and returns any response frames that
  should be sent back to the client.
  """
  @spec recv(t(), binary(), binary()) :: {:ok, [binary()], t()} | {:error, term(), t()}
  def recv(%__MODULE__{} = session, message, reply_payload \\ <<>>) when is_binary(message) and
                                                                           is_binary(reply_payload) do
    do_recv(session, message, reply_payload)
  end

  def recv(%__MODULE__{status: status} = session, _message, _payload) do
    {:error, {:invalid_state, status}, session}
  end

  @doc """
  Sends the next handshake message when the server is expected to transmit a
  payload (mainly useful in tests).
  """
  @spec send(t(), binary()) :: {:ok, [binary()], t()} | {:error, term(), t()}
  def send(%__MODULE__{} = session, payload \\ <<>>) when is_binary(payload) do
    do_send(session, payload, [])
  end

  def send(%__MODULE__{status: status} = session, _payload) do
    {:error, {:invalid_state, status}, session}
  end

  @doc """
  Encrypts a plaintext payload using the negotiated `tx` cipher state. Returns
  the ciphertext and an updated session struct.
  """
  @spec encrypt(t(), binary(), binary()) :: {:ok, binary(), t()} | {:error, term(), t()}
  def encrypt(%__MODULE__{status: :established, tx: tx} = session, plaintext, aad \\ <<>>)
      when is_binary(plaintext) and is_binary(aad) do
    case :enoise_cipher_state.encrypt_with_ad(tx, aad, plaintext) do
      {:ok, tx1, ciphertext} ->
        {:ok, ciphertext, %{session | tx: tx1}}

      {:error, reason} ->
        {:error, reason, session}
    end
  end

  def encrypt(%__MODULE__{} = session, _plaintext, _aad) do
    {:error, :handshake_incomplete, session}
  end

  @doc """
  Decrypts a ciphertext payload using the negotiated `rx` cipher state.
  """
  @spec decrypt(t(), binary(), binary()) :: {:ok, binary(), t()} | {:error, term(), t()}
  def decrypt(%__MODULE__{status: :established, rx: rx} = session, ciphertext, aad \\ <<>>)
      when is_binary(ciphertext) and is_binary(aad) do
    case :enoise_cipher_state.decrypt_with_ad(rx, aad, ciphertext) do
      {:ok, rx1, plaintext} ->
        {:ok, plaintext, %{session | rx: rx1}}

      {:error, reason} ->
        {:error, reason, session}
    end
  end

  def decrypt(%__MODULE__{} = session, _ciphertext, _aad) do
    {:error, :handshake_incomplete, session}
  end

  @doc """
  Rekeys the underlying cipher state. Accepts `:tx`, `:rx` or `:both`.
  """
  @spec rekey(t(), :tx | :rx | :both) :: {:ok, t()} | {:error, term(), t()}
  def rekey(%__MODULE__{status: :established} = session, :tx) do
    {:ok, %{session | tx: :enoise_cipher_state.rekey(session.tx)}}
  end

  def rekey(%__MODULE__{status: :established} = session, :rx) do
    {:ok, %{session | rx: :enoise_cipher_state.rekey(session.rx)}}
  end

  def rekey(%__MODULE__{} = session, :both) do
    with {:ok, session} <- rekey(session, :tx),
         {:ok, session} <- rekey(session, :rx) do
      {:ok, session}
    end
  end

  def rekey(%__MODULE__{} = session, _direction) do
    {:error, :handshake_incomplete, session}
  end

  @doc """
  Returns the negotiated session token once the handshake completes.
  """
  @spec token(t()) :: binary() | nil
  def token(%__MODULE__{token: token}), do: token

  @doc """
  Returns the unique identifier assigned to the session.
  """
  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: id

  @doc """
  Returns the Noise handshake hash associated with the session.
  """
  @spec handshake_hash(t()) :: binary() | nil
  def handshake_hash(%__MODULE__{handshake_hash: handshake_hash}), do: handshake_hash

  @doc """
  Returns the remote static public key recorded during the handshake.
  """
  @spec remote_static(t()) :: binary() | nil
  def remote_static(%__MODULE__{remote_static: remote_static}), do: remote_static

  @doc """
  Attaches actor metadata to the session. The actor ties the Noise handshake to the
  logical account/profile/device that authenticated during the handshake.
  """
  @spec with_actor(t(), actor() | map()) :: t()
  def with_actor(%__MODULE__{} = session, actor) do
    %{session | actor: normalize_actor(actor)}
  end

  @doc """
  Returns the actor metadata stored on the session.
  """
  @spec actor(t()) :: {:ok, actor()} | :error
  def actor(%__MODULE__{actor: actor}) when is_map(actor), do: {:ok, actor}
  def actor(_), do: :error

  @doc """
  Builds an already-established session. This is primarily useful in tests or when the
  Noise handshake is completed elsewhere and the resulting session token needs to be
  registered with the in-memory registry.
  """
  @spec established_session(Keyword.t()) :: t()
  def established_session(opts) when is_list(opts) do
    actor =
      opts
      |> Keyword.fetch!(:actor)
      |> normalize_actor()

    token_bytes = Keyword.get(opts, :token_bytes, @default_token_bytes)
    token_generator = Keyword.get(opts, :token_generator, &:crypto.strong_rand_bytes/1)

    token =
      case Keyword.get(opts, :token) do
        nil -> token_generator.(token_bytes)
        value when is_binary(value) -> value
        other -> raise ArgumentError, "Noise session token must be a binary, got: #{inspect(other)}"
      end

    %__MODULE__{
      id: Keyword.get_lazy(opts, :id, fn -> UUID.uuid4() end),
      role: Keyword.get(opts, :role, :responder),
      status: :established,
      current_pattern: Keyword.get(opts, :current_pattern),
      handshake_state: nil,
      tx: Keyword.get(opts, :tx),
      rx: Keyword.get(opts, :rx),
      handshake_hash: Keyword.get(opts, :handshake_hash),
      remote_static: Keyword.get(opts, :remote_static),
      server_keypair: Keyword.get(opts, :server_keypair),
      prologue: Keyword.get(opts, :prologue, <<>>),
      token: token,
      token_bytes: token_bytes,
      token_generator: token_generator,
      pending_patterns: [],
      actor: actor,
      ephemeral_override: Keyword.get(opts, :ephemeral_override),
      remote_static_hint: Keyword.get(opts, :remote_static)
    }
  end

  defp init_session(patterns, opts) do
    {first_pattern, remaining} =
      case patterns do
        [pattern | rest] -> {pattern, rest}
        [] -> raise ArgumentError, "at least one Noise pattern must be provided"
      end

    server_static = Keyword.fetch!(opts, :server_static)
    validate_secret!(server_static)

    prologue = Keyword.get(opts, :prologue, KeyLoader.prologue())
    role = Keyword.get(opts, :role, :responder)
    token_bytes = Keyword.get(opts, :token_bytes, @default_token_bytes)
    token_generator = Keyword.get(opts, :token_generator, &default_token/1)
    id = Keyword.get_lazy(opts, :id, fn -> UUID.uuid4() end)
    remote_static_hint = Keyword.get(opts, :remote_static)
    remote_static_binary = maybe_binary(remote_static_hint)

    started_at = System.monotonic_time()

    session = %__MODULE__{
      id: id,
      role: role,
      status: :handshaking,
      current_pattern: nil,
      handshake_state: nil,
      tx: nil,
      rx: nil,
      handshake_hash: nil,
      remote_static: remote_static_binary,
      server_keypair: build_keypair(server_static),
      prologue: prologue,
      token: nil,
      token_bytes: token_bytes,
      token_generator: token_generator,
      pending_patterns: remaining,
      ephemeral_override: Keyword.get(opts, :ephemeral),
      remote_static_hint: remote_static_binary,
      started_at: started_at
    }

    telemetry_start(session, first_pattern)

    case apply_pattern(session, first_pattern) do
      {:ok, session} ->
        session

      {:error, reason, session} ->
        case switch_pattern(session, reason) do
          {:ok, session} -> session
          {:error, final_reason, _failed} ->
            telemetry_exception(session, final_reason)
            raise ArgumentError, "failed to initialise Noise session: #{inspect(final_reason)}"
        end
    end
  end

  defp do_recv(%__MODULE__{} = session, message, reply_payload) do
    case :enoise.step_handshake(session.handshake_state, {:rcvd, message}) do
      {:ok, :rcvd, _payload, state} ->
        session
        |> Map.put(:handshake_state, state)
        |> respond(reply_payload, [])

      {:ok, :done, split_state} ->
        {:ok, [], finalize_session(session, split_state)}

      {:error, reason} ->
        handle_step_error(session, reason, {:rcvd, message}, reply_payload)
    end
  end

  defp do_send(%__MODULE__{} = session, payload, replies) do
    case :enoise.step_handshake(session.handshake_state, {:send, payload}) do
      {:ok, :send, msg, state} ->
        session = %{session | handshake_state: state}
        respond(session, payload, replies ++ [msg])

      {:ok, :done, split_state} ->
        {:ok, replies, finalize_session(session, split_state)}

      {:error, reason} ->
        handle_step_error(session, reason, {:send, payload}, payload)
    end
  end

  defp respond(%__MODULE__{} = session, payload, replies) do
    case expecting(session) do
      :out -> do_send(session, payload, replies)
      :done -> finalize_handshake(session, replies)
      :in -> {:ok, replies, session}
    end
  end

  defp finalize_handshake(%__MODULE__{} = session, replies) do
    case :enoise.step_handshake(session.handshake_state, :done) do
      {:ok, :done, split_state} ->
        {:ok, replies, finalize_session(session, split_state)}

      {:error, reason} ->
        {:error, reason, %{session | status: {:error, reason}}}
    end
  end

  defp handle_step_error(%__MODULE__{} = session, reason, step, payload) do
    case switch_pattern(session, reason) do
      {:ok, session} ->
        case step do
          {:rcvd, message} -> do_recv(session, message, payload)
          {:send, _} -> do_send(session, payload, [])
        end

      {:error, final_reason, failed_session} ->
        telemetry_exception(failed_session, final_reason)
        {:error, final_reason, %{failed_session | status: {:error, final_reason}}}
    end
  end

  defp apply_pattern(%__MODULE__{} = session, pattern) do
    with {:ok, options} <- handshake_options(session, pattern),
         {:ok, state} <- :enoise.handshake(options, session.role) do
      {:ok, %{session | handshake_state: state, current_pattern: pattern, status: :handshaking}}
    else
      {:error, reason} ->
        {:error, reason, %{session | current_pattern: nil, handshake_state: nil}}
    end
  end

  defp switch_pattern(%__MODULE__{pending_patterns: []} = session, reason) do
    {:error, reason, %{session | current_pattern: nil, handshake_state: nil}}
  end

  defp switch_pattern(%__MODULE__{pending_patterns: [next | rest]} = session, _reason) do
    session = %{session | pending_patterns: rest, current_pattern: nil, handshake_state: nil}

    case apply_pattern(session, next) do
      {:ok, session} -> {:ok, session}
      {:error, next_reason, session} -> switch_pattern(session, next_reason)
    end
  end

  defp handshake_options(%__MODULE__{} = session, pattern) do
    with {:ok, noise} <- fetch_protocol(pattern),
         {:ok, base} <- base_options(session, noise),
         {:ok, with_ephemeral} <- maybe_put_ephemeral(base, session.ephemeral_override),
         {:ok, options} <- maybe_put_remote_static(with_ephemeral, pattern, session.remote_static_hint) do
      {:ok, options}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp base_options(%__MODULE__{} = session, noise) do
    {:ok,
     [
       {:noise, noise},
       {:prologue, session.prologue},
       {:s, session.server_keypair}
     ]}
  end

  defp maybe_put_ephemeral(options, nil), do: {:ok, options}

  defp maybe_put_ephemeral(options, {:keypair, keypair}), do: {:ok, Keyword.put(options, :e, keypair)}

  defp maybe_put_ephemeral(options, %{secret: secret} = map) when is_binary(secret) do
    public = Map.get(map, :public, KeyLoader.public_key(secret))
    {:ok, Keyword.put(options, :e, :enoise_keypair.new(:dh25519, secret, public))}
  end

  defp maybe_put_ephemeral(options, secret) when is_binary(secret) do
    public = KeyLoader.public_key(secret)
    {:ok, Keyword.put(options, :e, :enoise_keypair.new(:dh25519, secret, public))}
  end

  defp maybe_put_ephemeral(_options, other) do
    {:error, {:invalid_ephemeral, other}}
  end

  defp maybe_put_remote_static(options, pattern, remote_static)
       when pattern in [:ik] do
    cond do
      is_binary(remote_static) ->
        {:ok, Keyword.put(options, :rs, :enoise_keypair.new(:dh25519, remote_static))}

      true ->
        {:error, {:missing_remote_static, pattern}}
    end
  end

  defp maybe_put_remote_static(options, _pattern, _remote_static), do: {:ok, options}

  defp fetch_protocol(pattern) do
    case Map.fetch(@protocols, pattern) do
      {:ok, protocol} -> {:ok, protocol}
      :error -> {:error, {:unsupported_pattern, pattern}}
    end
  end

  defp finalize_session(%__MODULE__{} = session, split_state) do
    tx = Map.fetch!(split_state, :tx)
    rx = Map.fetch!(split_state, :rx)
    handshake_hash = Map.fetch!(split_state, :hs_hash)
    final_state = Map.get(split_state, :final_state)
    remote_static = extract_remote_static(final_state) || session.remote_static

    final_session = %{session |
      handshake_state: nil,
      tx: tx,
      rx: rx,
      handshake_hash: handshake_hash,
      remote_static: remote_static,
      status: :established,
      token: session.token_generator.(session.token_bytes)
    }

    telemetry_stop(final_session, :ok)

    final_session
  end

  defp normalize_actor(actor) when is_map(actor) do
    account_id = fetch_actor_value(actor, :account_id)
    profile_id = fetch_actor_value(actor, :profile_id)
    device_id = optional_actor_value(actor, :device_id)
    device_public_key = optional_actor_value(actor, :device_public_key)

    %{account_id: account_id, profile_id: profile_id}
    |> maybe_put_actor(:device_id, device_id)
    |> maybe_put_actor(:device_public_key, device_public_key)
  end

  defp normalize_actor(other) do
    raise ArgumentError, "Noise session actor must be a map, got: #{inspect(other)}"
  end

  defp fetch_actor_value(actor, key) do
    actor
    |> Map.get(key)
    |> Kernel.||(Map.get(actor, Atom.to_string(key)))
    |> case do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          raise ArgumentError, "Noise session actor missing #{inspect(key)} (got: #{inspect(value)})"
        else
          trimmed
        end

      other ->
        raise ArgumentError, "Noise session actor missing #{inspect(key)} (got: #{inspect(other)})"
    end
  end

  defp optional_actor_value(actor, key) do
    actor
    |> Map.get(key)
    |> Kernel.||(Map.get(actor, Atom.to_string(key)))
    |> case do
      nil -> nil
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed == "", do: nil, else: trimmed
      _ -> nil
    end
  end

  defp maybe_put_actor(map, _key, nil), do: map
  defp maybe_put_actor(map, key, value), do: Map.put(map, key, value)

  defp extract_remote_static(nil), do: nil

  defp extract_remote_static(final_state) do
    try do
      case :enoise_hs_state.remote_keys(final_state) do
        :undefined -> nil
        remote_keypair -> :enoise_keypair.pubkey(remote_keypair)
      end
    rescue
      _ -> nil
    end
  end

  defp telemetry_start(%__MODULE__{} = session, pattern) do
    metadata =
      session
      |> telemetry_metadata()
      |> Map.put(:pattern, pattern)

    :telemetry.execute([:messngr, :noise, :handshake, :start], %{}, metadata)
  end

  defp telemetry_stop(%__MODULE__{} = session, status) do
    measurements = %{duration: handshake_duration(session)}

    metadata =
      session
      |> telemetry_metadata()
      |> Map.put(:status, status)

    :telemetry.execute([:messngr, :noise, :handshake, :stop], measurements, metadata)
  end

  defp telemetry_exception(%__MODULE__{} = session, reason) do
    measurements = %{duration: handshake_duration(session)}

    metadata =
      session
      |> telemetry_metadata()
      |> Map.put(:reason, reason)

    :telemetry.execute([:messngr, :noise, :handshake, :exception], measurements, metadata)
  end

  defp telemetry_metadata(%__MODULE__{} = session) do
    %{
      session_id: session.id,
      role: session.role,
      pattern: session.current_pattern,
      status: session.status
    }
  end

  defp handshake_duration(%__MODULE__{started_at: started_at}) when is_integer(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :microsecond)
  end

  defp handshake_duration(_session), do: 0

  defp build_keypair(secret) do
    public = KeyLoader.public_key(secret)
    :enoise_keypair.new(:dh25519, secret, public)
  end

  defp maybe_binary(nil), do: nil
  defp maybe_binary(value) when is_binary(value), do: value

  defp maybe_binary(other) do
    raise ArgumentError, ":remote_static must be binary, got: #{inspect(other)}"
  end

  defp validate_secret!(secret) when is_binary(secret) and byte_size(secret) == 32, do: :ok

  defp validate_secret!(other) do
    raise ArgumentError, "Noise static key must be a 32-byte binary, got: #{inspect(other)}"
  end

  defp default_token(size) when is_integer(size) and size > 0 do
    :crypto.strong_rand_bytes(size)
  end
end
