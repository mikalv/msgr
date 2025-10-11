defmodule AuthProvider.DeviceHelperTest do
  use ExUnit.Case

  alias AuthProvider.DeviceHelper
  alias AuthProvider.Account.Device
  alias AuthProvider.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "register_device/1" do
    test "registers a new device with metadata" do
      payload = build_payload(app_info: %{"version" => "1.0.0"})

      assert {:ok, %Device{} = device} = DeviceHelper.register_device(payload)
      assert device.device_id == payload["keyData"]["deviceId"]
      assert device.public_key_sign == payload["keyData"]["pubkey"]
      assert get_in(device.metadata, ["app_info", "version"]) == "1.0.0"
      assert Map.has_key?(device.metadata, "last_seen_at")
    end
  end

  describe "find_or_register_device/1" do
    test "registers a new device if not found" do
      payload = build_payload(app_info: %{"version" => "1.0.0"})

      assert {:ok, %Device{} = device} = DeviceHelper.find_or_register_device(payload)
      assert device.device_id == payload["keyData"]["deviceId"]
      assert get_in(device.metadata, ["app_info", "version"]) == "1.0.0"
    end

    test "updates existing device context when found" do
      existing =
        %Device{
          device_id: "device_id",
          public_key_sign: "existing_sign",
          public_key_dh: "existing_dh",
          device_info: %{"os" => "ios"},
          metadata: %{"app_info" => %{"version" => "0.9.0"}}
        }
        |> Repo.insert!()

      payload =
        build_payload(
          device_id: existing.device_id,
          app_info: %{"version" => "1.2.3"},
          device_info: %{"os" => "android"}
        )

      assert {:ok, %Device{} = device} = DeviceHelper.find_or_register_device(payload)
      assert device.id == existing.id
      assert device.device_info == %{"os" => "android"}
      assert get_in(device.metadata, ["app_info", "version"]) == "1.2.3"
      assert Map.has_key?(device.metadata, "last_seen_at")
    end
  end

  describe "upsert_device_context/3" do
    test "returns error when device does not exist" do
      assert {:error, :not_found} =
               DeviceHelper.upsert_device_context("unknown", %{"os" => "ios"}, %{})
    end

    test "updates device info and metadata" do
      device =
        %Device{
          device_id: "existing",
          public_key_sign: "sign",
          public_key_dh: "dh",
          device_info: %{"os" => "ios"},
          metadata: %{"app_info" => %{"version" => "0.1.0"}}
        }
        |> Repo.insert!()

      assert {:ok, %Device{} = updated} =
               DeviceHelper.upsert_device_context("existing", %{"os" => "android"}, %{"version" => "1.0.0"})

      assert updated.device_info == %{"os" => "android"}
      assert get_in(updated.metadata, ["app_info", "version"]) == "1.0.0"
      assert Map.has_key?(updated.metadata, "last_seen_at")
    end
  end

  describe "find_by_device_id/1" do
    test "finds device by id" do
      device =
        %Device{
          device_id: "lookup",
          public_key_sign: "sign",
          public_key_dh: "dh",
          device_info: %{}
        }
        |> Repo.insert!()

      assert %Device{} = DeviceHelper.find_by_device_id(device.device_id)
    end
  end

  defp build_payload(opts) do
    device_id = Keyword.get(opts, :device_id, "device_id")
    device_info = Keyword.get(opts, :device_info, %{"os" => "android"})
    app_info = Keyword.get(opts, :app_info, %{})

    %{
      "keyData" => %{
        "deviceId" => device_id,
        "pubkey" => "public_key",
        "dhpubkey" => "dh_public_key",
        "signature" => Base.encode64("signature")
      },
      "deviceInfo" => device_info,
      "appInfo" => app_info
    }
  end
end
