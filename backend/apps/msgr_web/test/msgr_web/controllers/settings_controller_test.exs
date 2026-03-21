defmodule MessngrWeb.SettingsControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Settings User"})
    profile = hd(account.profiles)
    conn = attach_jwt_session(conn, account, profile)

    %{conn: conn, account: account, profile: profile}
  end

  describe "GET /api/settings" do
    test "returns defaults for a new user", %{conn: conn, account: account} do
      conn = get(conn, "/api/settings")
      resp = json_response(conn, 200)

      assert resp["account_id"] == account.id
      assert resp["notify_desktop"] == true
      assert resp["notify_mobile"] == true
      assert resp["locale"] == "en"
      assert resp["time_24h"] == true
      assert resp["dnd_enabled"] == false
      assert resp["show_online_status"] == true
    end

    test "returns 401 without JWT", %{account: _account} do
      conn = build_conn()
      conn = get(conn, "/api/settings")
      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/settings" do
    test "updates and returns new settings", %{conn: conn} do
      conn =
        put(conn, "/api/settings", %{
          "locale" => "nb",
          "dnd_enabled" => true,
          "notify_sounds" => false
        })

      resp = json_response(conn, 200)
      assert resp["locale"] == "nb"
      assert resp["dnd_enabled"] == true
      assert resp["notify_sounds"] == false
      # Unchanged defaults remain
      assert resp["notify_desktop"] == true
    end

    test "persists across requests", %{conn: conn} do
      put(conn, "/api/settings", %{"status_text" => "Busy"})

      conn2 = get(conn, "/api/settings")
      resp = json_response(conn2, 200)
      assert resp["status_text"] == "Busy"
    end

    test "returns 401 without JWT" do
      conn = build_conn()
      conn = put(conn, "/api/settings", %{"locale" => "nb"})
      assert json_response(conn, 401)
    end
  end
end
