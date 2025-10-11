defmodule AuthProvider.ApiControllerDeviceTest do
  use AuthProvider.ConnCase, async: true

  alias AuthProvider.Account.Device
  alias AuthProvider.Account.User
  alias AuthProvider.Repo

  @refresh_opts [ttl: {4, :weeks}, token_type: "refresh"]

  setup %{conn: conn} do
    device =
      %Device{
        device_id: "device-123",
        public_key_sign: "pub",
        public_key_dh: "dh",
        device_info: %{},
        metadata: %{}
      }
      |> Repo.insert!()

    user =
      %User{
        email: "test@example.com"
      }
      |> Repo.insert!()

    {:ok, refresh_token, _claims} =
      AuthProvider.Guardian.encode_and_sign(user, %{}, @refresh_opts)

    %{conn: conn, device: device, user: user, refresh_token: refresh_token}
  end

  test "device_context updates device information", %{conn: conn, device: device} do
    payload = %{
      "from" => device.device_id,
      "deviceInfo" => %{"os" => "android"},
      "appInfo" => %{"version" => "1.0.0"}
    }

    conn = post(conn, ~p"/api/v1/device/context", payload)
    assert %{"status" => "ok"} = json_response(conn, 200)

    updated = Repo.get(Device, device.id)
    assert updated.device_info == %{"os" => "android"}
    assert get_in(updated.metadata, ["app_info", "version"]) == "1.0.0"
    assert Map.has_key?(updated.metadata, "last_seen_at")
  end

  test "device_context returns not found for unknown devices", %{conn: conn} do
    payload = %{"from" => "missing", "deviceInfo" => %{}, "appInfo" => %{}}

    conn = post(conn, ~p"/api/v1/device/context", payload)
    assert %{"error" => "device_not_found"} = json_response(conn, 404)
  end

  test "refresh_token issues new tokens", %{conn: conn, device: device, refresh_token: refresh_token, user: user} do
    conn =
      post(conn, ~p"/api/v1/refresh_token", %{
        "from" => device.device_id,
        "token" => refresh_token
      })

    body = json_response(conn, 200)
    assert body["status"] == "ok"
    assert is_binary(body["token"])
    assert is_binary(body["refresh_token"])
    assert body["uid"] == user.id

    updated = Repo.get(Device, device.id)
    assert Map.has_key?(updated.metadata, "last_seen_at")
  end
end
