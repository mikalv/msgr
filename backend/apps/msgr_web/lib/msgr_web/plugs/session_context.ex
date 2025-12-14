defmodule MessngrWeb.Plugs.SessionContext do
  @moduledoc """
  Extract session context from headers injected by Rust Gateway.

  The Rust Gateway validates Noise sessions and injects authenticated session
  information via HTTP headers:
  - X-Account-Id
  - X-Profile-Id
  - X-Device-Id
  - X-Session-Id

  This plug reads these headers and loads the corresponding database records,
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
    # Extract headers set by Rust Gateway
    account_id = get_req_header(conn, "x-account-id") |> List.first()
    profile_id = get_req_header(conn, "x-profile-id") |> List.first()
    device_id = get_req_header(conn, "x-device-id") |> List.first()
    session_id = get_req_header(conn, "x-session-id") |> List.first()

    if account_id || profile_id do
      Logger.debug("Session context from Rust Gateway",
        account_id: account_id,
        profile_id: profile_id,
        session_id: session_id
      )
    end

    conn
    |> assign(:current_account_id, account_id)
    |> assign(:current_profile_id, profile_id)
    |> assign(:current_device_id, device_id)
    |> assign(:session_id, session_id)
    |> load_current_account()
    |> load_current_profile()
    |> load_current_device()
    |> validate_authentication()
  end

  defp load_current_account(%{assigns: %{current_account_id: nil}} = conn), do: conn

  defp load_current_account(%{assigns: %{current_account_id: account_id}} = conn) do
    account = Accounts.get_account!(account_id)
    assign(conn, :current_account, account)
  rescue
    error ->
      Logger.warning("Account not found from Rust Gateway headers",
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
      Logger.warning("Profile not found from Rust Gateway headers",
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
