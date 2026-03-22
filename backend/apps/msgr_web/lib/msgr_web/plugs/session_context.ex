defmodule MessngrWeb.Plugs.SessionContext do
  @moduledoc """
  Extract session context from JWT Bearer token or headers injected by Rust Gateway.

  Authentication priority:
  1. Authorization: Bearer <JWT> header — decode JWT, extract account_id, profile_id, teams
  2. X-Account-Id / X-Profile-Id / X-Device-Id / X-Session-Id headers (backward compat)

  This plug reads the authentication data and loads the corresponding database records,
  making them available to controllers and channels via assigns.
  """

  import Plug.Conn
  require Logger

  alias Messngr.Accounts

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_jwt_from_header(conn) do
      {:ok, claims} ->
        Logger.debug("Session context from JWT",
          account_id: claims["sub"],
          profile_id: claims["pid"]
        )

        conn
        |> assign(:current_account_id, claims["sub"])
        |> assign(:current_profile_id, claims["pid"])
        |> assign(:current_device_id, nil)
        |> assign(:session_id, nil)
        |> assign(:jwt_teams, claims["ten"])
        |> load_current_account()
        |> load_current_profile()
        |> validate_authentication()

      :error ->
        # No valid JWT — reject
        respond_unauthorized(conn)
    end
  end

  defp get_jwt_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] ->
        case AuthProvider.Guardian.decode_and_verify(token, %{"typ" => "access"}) do
          {:ok, claims} -> {:ok, claims}
          {:error, _reason} -> :error
        end

      _ ->
        :error
    end
  end

  defp load_current_account(%{assigns: %{current_account_id: nil}} = conn), do: conn

  defp load_current_account(%{assigns: %{current_account_id: account_id}} = conn) do
    account = Accounts.get_account!(account_id)
    assign(conn, :current_account, account)
  rescue
    error ->
      Logger.warning("Account not found",
        account_id: account_id,
        error: inspect(error)
      )

      conn
  end

  defp load_current_profile(%{assigns: %{current_profile_id: nil}} = conn), do: conn

  defp load_current_profile(%{assigns: %{current_profile_id: profile_id}} = conn) do
    profile = Accounts.get_profile!(profile_id)

    # Verify profile belongs to the account
    if conn.assigns[:current_account] && profile.account_id == conn.assigns.current_account.id do
      assign(conn, :current_profile, profile)
    else
      Logger.warning("Profile-Account mismatch",
        profile_id: profile_id,
        profile_account_id: profile.account_id,
        current_account_id: conn.assigns[:current_account_id]
      )

      conn
    end
  rescue
    error ->
      Logger.warning("Profile not found",
        profile_id: profile_id,
        error: inspect(error)
      )

      conn
  end

  defp load_current_device(%{assigns: %{current_device_id: nil}} = conn), do: conn

  defp load_current_device(%{assigns: %{current_device_id: device_id}} = conn) do
    device = Accounts.get_device!(device_id)

    # Verify device belongs to the account
    if conn.assigns[:current_account] && device.account_id == conn.assigns.current_account.id do
      if device.enabled do
        assign(conn, :current_device, device)
      else
        Logger.warning("Device is disabled", device_id: device_id)
        conn
      end
    else
      Logger.warning("Device-Account mismatch",
        device_id: device_id,
        device_account_id: device.account_id,
        current_account_id: conn.assigns[:current_account_id]
      )

      conn
    end
  rescue
    error ->
      Logger.debug("Device not found (optional)",
        device_id: device_id,
        error: inspect(error)
      )

      conn
  end

  defp validate_authentication(conn) do
    # If authentication is required and we don't have an account/profile, return 401
    if conn.assigns[:current_account] && conn.assigns[:current_profile] do
      conn
    else
      respond_unauthorized(conn)
    end
  end

  defp respond_unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:unauthorized, Jason.encode!(%{error: "missing or invalid session"}))
    |> halt()
  end
end
