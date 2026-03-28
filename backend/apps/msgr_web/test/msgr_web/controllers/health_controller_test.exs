defmodule MessngrWeb.HealthControllerTest do
  use MessngrWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 with status", %{conn: conn} do
      conn = get(conn, "/health")
      resp = json_response(conn, 200)

      assert resp["status"] == "healthy"
      assert is_binary(resp["timestamp"])
      assert is_list(resp["backends"])
    end

    test "includes MessngrWeb.Endpoint backend", %{conn: conn} do
      conn = get(conn, "/health")
      resp = json_response(conn, 200)

      assert Enum.any?(resp["backends"], fn b ->
               b["name"] == "MessngrWeb.Endpoint" and b["status"] == "healthy"
             end)
    end
  end

  describe "GET /metrics" do
    test "returns 200 with prometheus-style metrics", %{conn: conn} do
      conn = get(conn, "/metrics")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/plain"

      body = conn.resp_body
      assert body =~ "msgr_backend_up"
      assert body =~ "# HELP"
      assert body =~ "# TYPE"
      assert body =~ "msgr_info"
    end

    test "includes backend gauge metric", %{conn: conn} do
      conn = get(conn, "/metrics")
      body = conn.resp_body

      assert body =~ ~s(msgr_backend_up{)
      assert body =~ ~s(name="MessngrWeb.Endpoint")
    end
  end
end
