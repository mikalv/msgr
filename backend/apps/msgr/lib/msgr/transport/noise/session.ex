defmodule Messngr.Transport.Noise.Session do
  @moduledoc """
  Lightweight representation of an established Noise session. The struct no
  lenger inneholder den aktive handshakestaten – Decibel håndterer det – men
  vi beholder feltene resten av kodebasen forventer: `id`, `token`,
  `handshake_hash`, `remote_static` og en valgfri `actor`.
  """

  alias UUID

  @enforce_keys [:id, :token, :handshake_hash, :remote_static, :prologue]
  defstruct [
    :id,
    :token,
    :token_bytes,
    :token_generator,
    :handshake_hash,
    :remote_static,
    :prologue,
    :actor,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          token: binary(),
          token_bytes: pos_integer(),
          token_generator: (pos_integer() -> binary()),
          handshake_hash: binary(),
          remote_static: binary(),
          prologue: binary(),
          actor: %{optional(atom()) => String.t()} | nil,
          metadata: map() | nil
        }

  @doc """
  Oppretter en etablert sesjon. Brukes i tester, registry og dev-handshake.
  """
  @spec established_session(keyword()) :: t()
  def established_session(opts) when is_list(opts) do
    actor =
      opts
      |> Keyword.fetch!(:actor)
      |> normalize_actor()

    token_bytes = Keyword.get(opts, :token_bytes, 32)
    token_generator = Keyword.get(opts, :token_generator, &:crypto.strong_rand_bytes/1)

    token =
      case Keyword.get(opts, :token) do
        nil -> token_generator.(token_bytes)
        value when is_binary(value) -> value
        other -> raise ArgumentError, "Noise session token must be binary, got: #{inspect(other)}"
      end

    handshake_hash =
      case Keyword.get(opts, :handshake_hash) do
        nil -> :crypto.strong_rand_bytes(32)
        value when is_binary(value) -> value
        other -> raise ArgumentError, "handshake_hash must be binary, got: #{inspect(other)}"
      end

    remote_static =
      opts
      |> Keyword.get(:remote_static, :crypto.strong_rand_bytes(32))
      |> ensure_binary!("remote_static")

    prologue =
      opts
      |> Keyword.get(:prologue, "")
      |> ensure_binary!("prologue")

    %__MODULE__{
      id: Keyword.get_lazy(opts, :id, &UUID.uuid4/0),
      token: token,
      token_bytes: token_bytes,
      token_generator: token_generator,
      handshake_hash: handshake_hash,
      remote_static: remote_static,
      prologue: prologue,
      actor: actor,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Henter tokenet fra sesjonen.
  """
  @spec token(t()) :: binary() | nil
  def token(%__MODULE__{token: token}), do: token

  @doc """
  Henter ID-en til sesjonen.
  """
  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: id

  @doc """
  Returnerer handshake-hashen.
  """
  @spec handshake_hash(t()) :: binary() | nil
  def handshake_hash(%__MODULE__{handshake_hash: hash}), do: hash

  @doc """
  Returnerer den lagrede remote static-nøkkelen (rå bytes).
  """
  @spec remote_static(t()) :: binary() | nil
  def remote_static(%__MODULE__{remote_static: remote_static}), do: remote_static

  @doc """
  Oppdaterer actor-informasjonen på sesjonen.
  """
  @spec with_actor(t(), map()) :: t()
  def with_actor(%__MODULE__{} = session, attrs) when is_map(attrs) do
    %__MODULE__{session | actor: normalize_actor(attrs)}
  end

  @doc """
  Leser actor-informasjonen dersom den finnes.
  """
  @spec actor(t()) :: {:ok, map()} | :error
  def actor(%__MODULE__{actor: actor}) when is_map(actor), do: {:ok, actor}
  def actor(_), do: :error

  defp ensure_binary!(value, field) do
    case value do
      bin when is_binary(bin) -> bin
      other -> raise ArgumentError, "#{field} must be binary, got: #{inspect(other)}"
    end
  end

  defp normalize_actor(%__MODULE__{} = session) do
    session.actor || %{}
  end

  defp normalize_actor(%{account_id: account_id, profile_id: profile_id} = attrs) do
    %{
      account_id: ensure_string!(account_id, :account_id),
      profile_id: ensure_string!(profile_id, :profile_id),
      device_id: optional_string(Map.get(attrs, :device_id)),
      device_public_key: optional_string(Map.get(attrs, :device_public_key))
    }
  end

  defp normalize_actor(%{"account_id" => account_id, "profile_id" => profile_id} = attrs) do
    %{
      account_id: ensure_string!(account_id, :account_id),
      profile_id: ensure_string!(profile_id, :profile_id),
      device_id: optional_string(Map.get(attrs, "device_id")),
      device_public_key: optional_string(Map.get(attrs, "device_public_key"))
    }
  end

  defp normalize_actor(other) when is_map(other) do
    normalize_actor(%{
      account_id: Map.get(other, :account_id) || Map.get(other, "account_id"),
      profile_id: Map.get(other, :profile_id) || Map.get(other, "profile_id"),
      device_id: Map.get(other, :device_id) || Map.get(other, "device_id"),
      device_public_key:
        Map.get(other, :device_public_key) || Map.get(other, "device_public_key")
    })
  end

  defp ensure_string!(value, field) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      raise ArgumentError, "Noise session actor missing #{inspect(field)}"
    else
      trimmed
    end
  end

  defp ensure_string!(value, field) do
    raise ArgumentError, "Noise session actor missing #{inspect(field)} (got: #{inspect(value)})"
  end

  defp optional_string(nil), do: nil

  defp optional_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp optional_string(_), do: nil
end
