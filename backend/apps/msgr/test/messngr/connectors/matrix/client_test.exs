defmodule Messngr.Connectors.Matrix.ClientTest do
  use ExUnit.Case, async: true

  alias Messngr.Connectors.Matrix.Client

  setup do
    bypass = Bypass.open()
    start_supervised!({Finch, name: __MODULE__.Finch})
    {:ok, bypass: bypass}
  end

  test "login posts credentials", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/_matrix/client/v3/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["identifier"]["user"] == "alice"
      assert payload["password"] == "secret"

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"access_token" => "token"}))
    end)

    assert {:ok, %{"access_token" => "token"}} =
             Client.login("alice", "secret", base_url: "http://localhost:#{bypass.port}", finch: __MODULE__.Finch)
  end

  test "sync forwards params", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/_matrix/client/v3/sync", fn conn ->
      assert conn.query_string =~ "access_token=token"
      assert conn.query_string =~ "since=123"
      assert conn.query_string =~ "timeout=30000"

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"next_batch" => "124"}))
    end)

    assert {:ok, %{"next_batch" => "124"}} =
             Client.sync(
               "token",
               %{since: "123", timeout: 30_000},
               base_url: "http://localhost:#{bypass.port}",
               finch: __MODULE__.Finch
             )
  end

  test "send_event uses provided txn id", %{bypass: bypass} do
    Bypass.expect_once(bypass, "PUT", ~r|/_matrix/client/v3/rooms/!room:server/send/m\.room\.message/custom-txn|, fn conn ->
      assert conn.query_string == "access_token=token"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      assert payload["body"] == "hi"

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"event_id" => "$event"}))
    end)

    assert {:ok, %{"event_id" => "$event"}} =
             Client.send_event(
               "token",
               "!room:server",
               %{"msgtype" => "m.text", "body" => "hi"},
               base_url: "http://localhost:#{bypass.port}",
               finch: __MODULE__.Finch,
               txn_id: "custom-txn"
             )
  end
end
