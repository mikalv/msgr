defmodule MessngrWeb.Plugs.CurrentActor do
  @moduledoc """
  Loads the current account and profile from headers.
  - `x-account-id`: binary_id for kontoen
  - `x-profile-id`: binary_id for aktiv profil
  """

  import Plug.Conn

  alias Messngr

  def init(opts), do: opts

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
        |> send_resp(:unauthorized, ~s({"error":"missing or invalid account/profile headers"}))
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
