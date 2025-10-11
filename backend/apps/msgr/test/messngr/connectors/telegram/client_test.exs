defmodule Messngr.Connectors.Telegram.ClientTest do
  use ExUnit.Case, async: true

  alias Messngr.Connectors.Telegram.Client

  setup do
    bypass = Bypass.open()
    finch = start_supervised!({Finch, name: __MODULE__.Finch})

    {:ok, bypass: bypass, finch: finch}
  end

  test "send_message posts payload", %{bypass: bypass, finch: finch} do
    token = "abc"
    chat_id = 123

    Bypass.expect_once(bypass, "POST", "/bot#{token}/sendMessage", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["chat_id"] == chat_id
      assert payload["text"] == "hello"
      assert payload["parse_mode"] == "MarkdownV2"

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
    end)

    assert {:ok, %{"ok" => true}} =
             Client.send_message(
               token,
               chat_id,
               "hello",
               parse_mode: "MarkdownV2",
               base_url: "http://localhost:#{bypass.port}",
               finch: __MODULE__.Finch
             )
  end

  test "get_updates forwards query params", %{bypass: bypass, finch: finch} do
    token = "abc"

    Bypass.expect_once(bypass, "GET", "/bot#{token}/getUpdates", fn conn ->
      assert conn.query_string =~ "offset=10"
      assert conn.query_string =~ "limit=50"
      assert conn.query_string =~ "timeout=2"
      assert conn.query_string =~ "allowed_updates=%5B%22message%22%5D"

      Plug.Conn.resp(conn, 200, Jason.encode!(%{"ok" => true, "result" => []}))
    end)

    assert {:ok, %{"ok" => true, "result" => []}} =
             Client.get_updates(
               token,
               offset: 10,
               limit: 50,
               timeout: 2,
               allowed_updates: ["message"],
               base_url: "http://localhost:#{bypass.port}",
               finch: __MODULE__.Finch
             )
  end

  test "propagates decode errors", %{bypass: bypass, finch: finch} do
    token = "abc"

    Bypass.expect_once(bypass, "GET", "/bot#{token}/getUpdates", fn conn ->
      Plug.Conn.resp(conn, 200, "not-json")
    end)

    assert {:error, {:decode_error, _}} =
             Client.get_updates(token, base_url: "http://localhost:#{bypass.port}", finch: __MODULE__.Finch)
  end
end
