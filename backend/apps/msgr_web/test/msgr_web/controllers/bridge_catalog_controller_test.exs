defmodule MessngrWeb.BridgeCatalogControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Bridges

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Catalog Owner"})
    profile = hd(account.profiles)
    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn, account: account}
  end

  test "lists bridge catalog", %{conn: conn} do
    conn = get(conn, ~p"/api/bridges/catalog")

    assert %{"data" => data} = json_response(conn, 200)
    assert Enum.any?(data, &(&1["id"] == "telegram"))
  end

  test "filters by status", %{conn: conn} do
    conn = get(conn, ~p"/api/bridges/catalog", %{status: "available"})

    assert %{"data" => data} = json_response(conn, 200)
    assert Enum.all?(data, &(&1["status"] == "available"))
  end

  test "marks linked connectors", %{conn: conn, account: account} do
    assert {:ok, _record} =
             Bridges.sync_linked_identity(account.id, :telegram, %{external_id: "tg-123"})

    conn = get(conn, ~p"/api/bridges/catalog")

    assert %{"data" => data} = json_response(conn, 200)
    telegram = Enum.find(data, &(&1["id"] == "telegram"))

    assert telegram["auth"]["status"] == "linked"
    assert telegram["link"]["external_id"] == "tg-123"
  end

  test "returns all linked instances for multi-tenant connectors", %{conn: conn, account: account} do
    assert {:ok, _} =
             Bridges.sync_linked_identity(account.id, :slack, %{external_id: "one"}, instance: "workspace-a")

    assert {:ok, _} =
             Bridges.sync_linked_identity(account.id, :slack, %{external_id: "two"}, instance: "workspace-b")

    conn = get(conn, ~p"/api/bridges/catalog")

    assert %{"data" => data} = json_response(conn, 200)
    slack = Enum.find(data, &(&1["id"] == "slack"))

    assert slack["auth"]["status"] == "linked"
    assert slack["link"]["connections"] |> length() == 2
    assert Enum.any?(slack["link"]["connections"], &(&1["instance"] == "workspace-a"))
    assert Enum.any?(slack["link"]["connections"], &(&1["instance"] == "workspace-b"))
  end

  test "requires authentication" do
    conn = build_conn()

    conn = get(conn, ~p"/api/bridges/catalog")
    assert json_response(conn, 401) == %{"error" => "missing or invalid noise session"}
  end
end
