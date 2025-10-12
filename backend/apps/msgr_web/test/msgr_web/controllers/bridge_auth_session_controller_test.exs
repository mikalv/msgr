defmodule MessngrWeb.BridgeAuthSessionControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Session Owner"})
    profile = hd(account.profiles)
    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn, account: account}
  end

  test "creates a bridge auth session", %{conn: conn} do
    payload = %{client_context: %{platform: "desktop"}}

    conn = post(conn, ~p"/api/bridges/telegram/sessions", payload)

    assert %{"data" => data} = json_response(conn, 200)
    assert data["service"] == "telegram"
    assert data["state"] == "awaiting_user"
    assert data["client_context"]["platform"] == "desktop"
    assert data["authorization_path"] =~ data["id"]
  end

  test "fetches a session", %{conn: conn} do
    conn = post(conn, ~p"/api/bridges/matrix/sessions", %{})
    %{"data" => %{"id" => session_id}} = json_response(conn, 200)

    conn = get(conn, ~p"/api/bridges/sessions/#{session_id}")

    assert %{"data" => %{"id" => ^session_id, "service" => "matrix"}} = json_response(conn, 200)
  end

  test "returns error for unknown connector", %{conn: conn} do
    conn = post(conn, ~p"/api/bridges/unknown/sessions", %{})

    assert %{"error" => "unknown_connector"} = json_response(conn, 400)
  end

  test "requires authentication" do
    conn = build_conn()
    conn = post(conn, ~p"/api/bridges/telegram/sessions", %{})

    assert json_response(conn, 401) == %{"error" => "missing or invalid noise session"}
  end
end
