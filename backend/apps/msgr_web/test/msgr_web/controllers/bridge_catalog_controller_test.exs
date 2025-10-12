defmodule MessngrWeb.BridgeCatalogControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Catalog Owner"})
    profile = hd(account.profiles)
    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn}
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

  test "requires authentication" do
    conn = build_conn()

    conn = get(conn, ~p"/api/bridges/catalog")
    assert json_response(conn, 401) == %{"error" => "missing or invalid noise session"}
  end
end
