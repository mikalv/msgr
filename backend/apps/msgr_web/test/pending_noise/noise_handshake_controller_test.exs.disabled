defmodule MessngrWeb.NoiseHandshakeControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Transport.Noise.Registry

  describe "POST /api/noise/handshake" do
    test "returns session metadata and persists it in the registry", %{conn: conn} do
      conn = post(conn, ~p"/api/noise/handshake")
      assert %{"data" => data} = json_response(conn, 200)

      assert is_binary(data["session_id"])
      assert is_binary(data["signature"])
      assert is_binary(data["device_key"])
      assert is_binary(data["device_private_key"])
      assert is_binary(data["expires_at"])

      assert %{"protocol" => protocol, "prologue" => prologue} = data["server"]
      assert protocol == Messngr.Noise.KeyLoader.protocol()
      assert prologue == Messngr.Noise.KeyLoader.prologue()

      assert {:ok, _session} = Registry.fetch(data["session_id"])
    end

    test "returns 503 when Noise transport is disabled", %{conn: conn} do
      original = Application.get_env(:msgr, :noise, [])

      try do
        Application.put_env(:msgr, :noise, Keyword.put(original, :enabled, false))
        conn = post(conn, ~p"/api/noise/handshake")
        assert json_response(conn, 503)
      after
        Application.put_env(:msgr, :noise, original)
      end
    end
  end
end
