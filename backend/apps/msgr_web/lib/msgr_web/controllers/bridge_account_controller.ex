defmodule MessngrWeb.BridgeAccountController do
  use MessngrWeb, :controller

  alias Messngr.Bridges

  action_fallback MessngrWeb.FallbackController

  def delete(conn, %{"bridge_id" => bridge_id}) do
    account = conn.assigns.current_account

    with {:ok, _account} <- Bridges.unlink_account(account, bridge_id) do
      send_resp(conn, :no_content, "")
    end
  end
end
