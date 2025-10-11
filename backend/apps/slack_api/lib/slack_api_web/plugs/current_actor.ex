defmodule SlackApiWeb.Plugs.CurrentActor do
  @moduledoc """
  Loads the current account and profile for Slack-compatible endpoints.

  The plug expects the same headers as the internal Msgr APIs:

    * `x-account-id` – UUID for the account/workspace.
    * `x-profile-id` – UUID for the active profile within that account.

  The Slack surface will later translate Slack tokens to these headers, but
  for now we reuse the simple header-based contract so the backend logic can
  be exercised end-to-end while we stub the auth layer.
  """

  import Plug.Conn

  alias Messngr

  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    with [account_id] <- get_req_header(conn, "x-account-id"),
         [profile_id] <- get_req_header(conn, "x-profile-id"),
         {:ok, account} <- fetch_account(account_id),
         {:ok, profile} <- fetch_profile(account, profile_id) do
      conn
      |> assign(:current_account, account)
      |> assign(:current_profile, profile)
    else
      _ ->
        conn
        |> send_resp(:unauthorized, ~s({"ok":false,"error":"invalid_auth"}))
        |> halt()
    end
  end

  defp fetch_account(account_id) do
    {:ok, Messngr.get_account!(account_id)}
  rescue
    _ -> :error
  end

  defp fetch_profile(account, profile_id) do
    profile = Messngr.get_profile!(profile_id)

    if profile.account_id == account.id do
      {:ok, profile}
    else
      :error
    end
  rescue
    _ -> :error
  end
end
