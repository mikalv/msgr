defmodule MessngrWeb.BridgeAccountController do
  use MessngrWeb, :controller

  alias Messngr.Bridges

  action_fallback MessngrWeb.FallbackController

  def delete(conn, %{"bridge_id" => bridge_id} = params) do
    account = conn.assigns.current_account
    opts = build_unlink_opts(params)

    with {:ok, _account} <- Bridges.unlink_account(account, bridge_id, opts) do
      send_resp(conn, :no_content, "")
    end
  end

  defp build_unlink_opts(params) do
    case Map.get(params, "instance") do
      nil -> []
      instance -> [instance: instance]
    end
  end
end
