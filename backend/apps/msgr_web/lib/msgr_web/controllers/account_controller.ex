defmodule MessngrWeb.AccountController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, _params) do
    accounts = Messngr.list_accounts()
    render(conn, :index, accounts: accounts)
  end

  def create(conn, params) do
    case Messngr.create_account(params) do
      {:ok, account} ->
        conn
        |> put_status(:created)
        |> render(:show, account: account)

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
