defmodule MessngrWeb.BridgeAuthSessionController do
  use MessngrWeb, :controller

  alias Messngr.Bridges.Auth

  action_fallback MessngrWeb.FallbackController

  def create(conn, %{"bridge_id" => bridge_id} = params) do
    account = conn.assigns.current_account
    attrs =
      params
      |> Map.get("session", %{})
      |> Map.merge(Map.drop(params, ["bridge_id", "session"]))

    with {:ok, session} <- Auth.start_session(account, bridge_id, attrs) do
      render(conn, :show, session: session)
    end
  end

  def show(conn, %{"id" => id}) do
    account = conn.assigns.current_account

    with {:ok, session} <- Auth.fetch_session(account, id) do
      render(conn, :show, session: session)
    end
  end

  def submit_credentials(conn, %{"bridge_id" => bridge_id, "id" => session_id} = params) do
    account = conn.assigns.current_account
    credentials = Map.get(params, "credentials", %{})

    with {:ok, session, _summary} <- Auth.submit_credentials(account, bridge_id, session_id, credentials) do
      render(conn, :show, session: session)
    end
  end
end
