defmodule MessngrWeb.Plugs.NoiseSession do
  @moduledoc """
  Plug and helper utilities for resolving the current actor from a Noise session
  token. The module can be used both in REST pipelines (Plug.Conn) and in
  WebSocket contexts (`MessngrWeb.UserSocket`) to ensure account/profile/device
  assignments remain consistent across transports.
  """

  import Plug.Conn

  alias Messngr
  alias Messngr.Noise.SessionStore
  alias Messngr.Noise.SessionStore.Actor, as: NoiseActor
  alias Messngr.Transport.Noise.Session
  alias Messngr.{Accounts, Repo}

  defmodule Actor do
    @moduledoc """
    Fully resolved actor for the current request/socket.
    """

    @enforce_keys [:token, :encoded_token, :session, :account, :profile]
    defstruct [:token, :encoded_token, :session, :account, :profile, :device]

    @type t :: %__MODULE__{
            token: binary(),
            encoded_token: String.t(),
            session: Session.t(),
            account: Accounts.Account.t(),
            profile: Accounts.Profile.t(),
            device: Accounts.Device.t() | nil
          }
  end

  @behaviour Plug

  @impl Plug
  def init(opts) do
    opts
    |> Enum.into(%{})
    |> Map.put_new(:allow_legacy_headers, Application.get_env(:msgr_web, :legacy_actor_headers, false))
    |> Map.put_new(:assign_session, true)
  end

  @impl Plug
  def call(conn, opts) do
    opts = init(opts)

    case ensure_actor(conn, opts) do
      {:ok, conn} -> conn
      {:error, reason} -> respond_unauthorized(conn, reason)
    end
  end

  @doc """
  Verifies the provided encoded Noise session token and returns the fully
  resolved actor.
  """
  @spec verify_token(String.t(), keyword()) :: {:ok, Actor.t()} | {:error, term()}
  def verify_token(encoded_token, opts \\ [])
  def verify_token(encoded_token, opts) when is_binary(encoded_token) do
    with {:ok, raw_token} <- decode_token(encoded_token),
         {:ok, session, %NoiseActor{} = actor} <- SessionStore.fetch(raw_token, opts),
         {:ok, account} <- load_account(actor.account_id),
         {:ok, profile} <- load_profile(account, actor.profile_id),
         {:ok, device} <- load_device(account, actor) do
      {:ok,
       %Actor{
         token: raw_token,
         encoded_token: SessionStore.encode_token(raw_token),
         session: session,
         account: account,
         profile: profile,
         device: device
       }}
    else
      :error -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify_token(_other, _opts), do: {:error, :invalid_token}

  @doc """
  Encodes a raw Noise session token using the same representation expected by the
  plug.
  """
  @spec encode_token(binary()) :: String.t()
  def encode_token(token), do: SessionStore.encode_token(token)

  @doc """
  Attempts to decode an encoded Noise token. Returns `{:ok, binary}` on success.
  """
  @spec decode_token(String.t()) :: {:ok, binary()} | :error
  def decode_token(token), do: SessionStore.decode_token(token)

  defp ensure_actor(conn, opts) do
    case fetch_token(conn) do
      {:ok, token, source} ->
        with {:ok, actor} <- verify_token(token, opts) do
          conn
          |> assign_noise_actor(actor, opts)
          |> maybe_store_session(actor, source, opts)
          |> then(&{:ok, &1})
        end

      :legacy when opts.allow_legacy_headers -> legacy_headers(conn)
      {:error, reason} -> {:error, reason}
      :legacy -> {:error, :invalid_token}
    end
  end

  defp fetch_token(conn) do
    with :error <- fetch_authorization_token(conn),
         :error <- fetch_noise_header(conn),
         :error <- fetch_session_token(conn) do
      if legacy_headers_present?(conn) do
        :legacy
      else
        {:error, :missing_token}
      end
    end
  end

  defp fetch_authorization_token(conn) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> case do
      "Noise " <> token -> normalize_token(token, :authorization)
      "Bearer " <> token -> normalize_token(token, :authorization)
      _ -> :error
    end
  end

  defp fetch_noise_header(conn) do
    conn
    |> get_req_header("x-noise-session")
    |> List.first()
    |> case do
      token when is_binary(token) -> normalize_token(token, :header)
      _ -> :error
    end
  end

  defp fetch_session_token(conn) do
    case get_session(conn, :noise_session_token) do
      token when is_binary(token) and byte_size(token) > 0 -> {:ok, token, :session}
      _ -> :error
    end
  end

  defp normalize_token(token, source) do
    token
    |> String.trim()
    |> case do
      "" -> :error
      trimmed -> {:ok, trimmed, source}
    end
  end

  defp legacy_headers_present?(conn) do
    get_req_header(conn, "x-account-id") != [] and get_req_header(conn, "x-profile-id") != []
  end

  defp legacy_headers(conn) do
    with [account_id] <- get_req_header(conn, "x-account-id"),
         [profile_id] <- get_req_header(conn, "x-profile-id"),
         {:ok, account} <- load_account(account_id),
         {:ok, profile} <- load_profile(account, profile_id) do
      conn
      |> assign(:current_account, account)
      |> assign(:current_profile, profile)
      |> then(&{:ok, &1})
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp assign_noise_actor(conn, %Actor{} = actor, _opts) do
    conn
    |> assign(:noise_session, actor.session)
    |> assign(:noise_session_token, actor.encoded_token)
    |> assign(:current_account, actor.account)
    |> assign(:current_profile, actor.profile)
    |> maybe_assign_device(actor.device)
  end

  defp maybe_assign_device(conn, nil), do: conn
  defp maybe_assign_device(conn, device), do: assign(conn, :current_device, device)

  defp maybe_store_session(conn, actor, :authorization, opts), do: maybe_store_session(conn, actor, :header, opts)

  defp maybe_store_session(conn, actor, _source, %{assign_session: false}), do: conn

  defp maybe_store_session(conn, actor, _source, _opts) do
    put_session(conn, :noise_session_token, actor.encoded_token)
  end

  defp respond_unauthorized(conn, _reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:unauthorized, Jason.encode!(%{error: "missing or invalid noise session"}))
    |> halt()
  end

  defp load_account(account_id) do
    {:ok, Messngr.get_account!(account_id)}
  rescue
    _ -> {:error, :unknown_account}
  end

  defp load_profile(account, profile_id) do
    profile = Messngr.get_profile!(profile_id)

    if profile.account_id == account.id do
      {:ok, profile}
    else
      {:error, :profile_mismatch}
    end
  rescue
    _ -> {:error, :unknown_profile}
  end

  defp load_device(_account, %NoiseActor{device_id: nil, device_public_key: nil}), do: {:ok, nil}

  defp load_device(account, %NoiseActor{device_id: device_id}) when is_binary(device_id) do
    device = Messngr.get_device!(device_id)

    cond do
      device.account_id != account.id -> {:error, :device_mismatch}
      device.enabled == false -> {:error, :device_disabled}
      true -> {:ok, device}
    end
  rescue
    _ -> {:error, :unknown_device}
  end

  defp load_device(account, %NoiseActor{device_public_key: key}) when is_binary(key) do
    case Accounts.get_device_by_public_key(account.id, key) do
      %Accounts.Device{enabled: false} -> {:error, :device_disabled}
      %Accounts.Device{} = device -> {:ok, Repo.preload(device, [:account, :profile])}
      nil -> {:error, :unknown_device}
    end
  end

  defp load_device(_account, _actor), do: {:ok, nil}
end
