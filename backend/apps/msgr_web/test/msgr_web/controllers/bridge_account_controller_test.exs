defmodule MessngrWeb.BridgeAccountControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Bridges

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Bridge Owner"})
    profile = hd(account.profiles)
    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn, account: account}
  end

  test "unlinks an existing bridge account", %{conn: conn, account: account} do
    assert {:ok, _record} =
             Bridges.sync_linked_identity(account.id, :telegram, %{external_id: "tg-1"})

    conn = delete(conn, ~p"/api/bridges/telegram")
    assert response(conn, 204)
    assert Bridges.get_account(account.id, :telegram) == nil
  end

  test "unlinks a specific bridge instance", %{conn: conn, account: account} do
    assert {:ok, _} =
             Bridges.sync_linked_identity(account.id, :slack, %{external_id: "one"}, instance: "workspace-a")

    assert {:ok, _} =
             Bridges.sync_linked_identity(account.id, :slack, %{external_id: "two"}, instance: "workspace-b")

    conn = delete(conn, ~p"/api/bridges/slack?instance=workspace-a")
    assert response(conn, 204)

    assert Bridges.get_account(account.id, :slack, instance: "workspace-a") == nil
    assert Bridges.get_account(account.id, :slack, instance: "workspace-b")
  end

  test "returns not found when bridge is not linked", %{conn: conn} do
    conn = delete(conn, ~p"/api/bridges/telegram")
    assert json_response(conn, 404) == %{"error" => "not_found"}
  end
end
