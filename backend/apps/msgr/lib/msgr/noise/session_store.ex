defmodule Messngr.Noise.SessionStore do
  @moduledoc """
  Helper around `Messngr.Transport.Noise.Registry` that keeps track of Noise
  session tokens and the associated account/profile/device metadata. The store
  exposes helpers for issuing synthetic sessions in tests while keeping the
  registry interaction consistent with the runtime Noise handshake.
  """

  alias Messngr.Transport.Noise.{Registry, Session}

  defmodule Actor do
    @moduledoc """
    Normalised representation of the account/profile/device tied to a Noise
    session token.
    """

    @enforce_keys [:account_id, :profile_id]
    defstruct [:account_id, :profile_id, :device_id, :device_public_key]

    @type t :: %__MODULE__{
            account_id: String.t(),
            profile_id: String.t(),
            device_id: String.t() | nil,
            device_public_key: String.t() | nil
          }
  end

  @type actor_input :: Actor.t() | map()

  @doc """
  Issues a ready-to-use Noise session token for the provided actor metadata and
  stores it in the registry. This is primarily intended for tests until the
  full handshake pipeline provisions sessions automatically.
  """
  @spec issue(actor_input(), keyword()) :: {:ok, Session.t()}
  def issue(actor, opts \\ []) do
    actor = normalize_actor(actor)

    session =
      opts
      |> Keyword.put(:actor, Map.from_struct(actor))
      |> Session.established_session()

    registry = Keyword.get(opts, :registry, Registry)
    {:ok, session} = Registry.put(registry, session)
    emit_token_event(:issue, session, actor)
    {:ok, session}
  end

  @doc """
  Attaches actor metadata to an existing session and persists it in the
  registry. Useful when the caller performed the Noise handshake externally and
  needs to register the resulting session token.
  """
  @spec register(Session.t(), actor_input(), keyword()) :: {:ok, Session.t()}
  def register(%Session{} = session, actor, opts \\ []) do
    actor = normalize_actor(actor)
    registry = Keyword.get(opts, :registry, Registry)

    session = Session.with_actor(session, Map.from_struct(actor))

    with {:ok, session} <- Registry.put(registry, session) do
      emit_token_event(:register, session, actor)
      {:ok, session}
    end
  end

  @doc """
  Fetches the session identified by the raw token and returns both the session
  and the normalised actor metadata.
  """
  @spec fetch(binary(), keyword()) :: {:ok, Session.t(), Actor.t()} | :error
  def fetch(token, opts \\ []) when is_binary(token) do
    registry = Keyword.get(opts, :registry, Registry)

    case Registry.fetch_by_token(registry, token) do
      {:ok, session} ->
        case Session.actor(session) do
          {:ok, actor_map} ->
            actor = actor_from_map(actor_map)
            Registry.touch_by_token(registry, token)
            emit_token_event(:verify, session, actor)
            {:ok, session, actor}

          :error ->
            emit_token_failure(:verify, :actor_missing, %{session_id: Session.id(session)})
            :error
        end

      :error ->
        emit_token_failure(:verify, :not_found, %{})
        :error
    end
  end

  @doc """
  Removes the session associated with the token from the registry.
  """
  @spec delete(binary(), keyword()) :: :ok | :error
  def delete(token, opts \\ []) when is_binary(token) do
    registry = Keyword.get(opts, :registry, Registry)
    Registry.delete_by_token(registry, token)
  end

  @doc """
  Encodes a raw Noise session token into a transport-safe string representation.
  """
  @spec encode_token(binary()) :: String.t()
  def encode_token(token) when is_binary(token) do
    Base.url_encode64(token, padding: false)
  end

  @doc """
  Attempts to decode an encoded Noise session token. Returns `{:ok, binary}` on
  success or `:error` when the token is malformed.
  """
  @spec decode_token(String.t()) :: {:ok, binary()} | :error
  def decode_token(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> Base.decode64(token)
    end
  end

  defp normalize_actor(%Actor{} = actor), do: actor

  defp normalize_actor(attrs) when is_map(attrs) do
    account_id = fetch_required(attrs, :account_id)
    profile_id = fetch_required(attrs, :profile_id)
    device_id = fetch_optional(attrs, :device_id)
    device_public_key = fetch_optional(attrs, :device_public_key)

    %Actor{
      account_id: account_id,
      profile_id: profile_id,
      device_id: device_id,
      device_public_key: device_public_key
    }
  end

  defp normalize_actor(other) do
    raise ArgumentError,
          "Noise session actor must be provided as a map or Actor struct, got: #{inspect(other)}"
  end

  defp actor_from_map(%{account_id: account_id, profile_id: profile_id} = map) do
    %Actor{
      account_id: account_id,
      profile_id: profile_id,
      device_id: Map.get(map, :device_id),
      device_public_key: Map.get(map, :device_public_key)
    }
  end

  defp actor_from_map(map) when is_map(map) do
    actor_from_map(%{
      account_id: Map.fetch!(map, "account_id"),
      profile_id: Map.fetch!(map, "profile_id"),
      device_id: Map.get(map, "device_id"),
      device_public_key: Map.get(map, "device_public_key")
    })
  end

  defp actor_from_map(other) do
    raise ArgumentError, "Unable to normalise Noise actor from: #{inspect(other)}"
  end

  defp fetch_required(attrs, key) do
    attrs
    |> Map.get(key)
    |> Kernel.||(Map.get(attrs, Atom.to_string(key)))
    |> case do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          raise ArgumentError,
                "Noise session actor missing #{inspect(key)} (got: #{inspect(value)})"
        else
          trimmed
        end

      other ->
        raise ArgumentError,
              "Noise session actor missing #{inspect(key)} (got: #{inspect(other)})"
    end
  end

  defp fetch_optional(attrs, key) do
    attrs
    |> Map.get(key)
    |> Kernel.||(Map.get(attrs, Atom.to_string(key)))
    |> case do
      nil -> nil
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed == "", do: nil, else: trimmed
      _ -> nil
    end
  end

  defp emit_token_event(event, %Session{} = session, %Actor{} = actor) do
    metadata = %{
      session_id: Session.id(session),
      account_id: actor.account_id,
      profile_id: actor.profile_id,
      device_id: actor.device_id
    }

    :telemetry.execute([:messngr, :noise, :token, event], %{count: 1}, metadata)
  end

  defp emit_token_failure(event, reason, metadata) do
    metadata = Map.put(metadata, :reason, reason)
    :telemetry.execute([:messngr, :noise, :token, event, :failure], %{count: 1}, metadata)
  end
end
