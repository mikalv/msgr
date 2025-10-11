defmodule AuthProvider.DeviceHelperTest do
  use ExUnit.Case, async: true
  alias AuthProvider.DeviceHelper
  alias AuthProvider.Account.Device
  alias AuthProvider.Repo

  @valid_key_data %{
    "signature" => Base.encode64("valid_signature"),
    "pubkey" => Base.encode64("valid_pubkey"),
    "deviceId" => "valid_device_id",
    "dhpubkey" => "valid_dhpubkey"
  }

  @valid_device_info %{
    "model" => "Test Model",
    "os" => "Test OS"
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "validate_device_signature/1" do
    test "validates the device signature successfully" do
      payload = %{"keyData" => @valid_key_data}
      assert DeviceHelper.validate_device_signature(payload)
    end

    test "fails to validate with incorrect signature" do
      invalid_key_data = Map.put(@valid_key_data, "signature", Base.encode64("invalid_signature"))
      payload = %{"keyData" => invalid_key_data}
      refute DeviceHelper.validate_device_signature(payload)
    end
  end

  describe "register_device/1" do
    test "registers a new device successfully" do
      payload = %{"keyData" => @valid_key_data, "deviceInfo" => @valid_device_info}
      assert {:ok, %Device{}} = DeviceHelper.register_device(payload)
    end
  end

  describe "find_or_register_device/1" do
    test "finds an existing device" do
      device = %Device{
        device_id: @valid_key_data["deviceId"],
        device_info: @valid_device_info,
        public_key_sign: @valid_key_data["pubkey"],
        public_key_dh: @valid_key_data["dhpubkey"]
      }
      Repo.insert!(device)

      payload = %{"keyData" => @valid_key_data, "deviceInfo" => @valid_device_info}
      assert {:ok, ^device} = DeviceHelper.find_or_register_device(payload)
    end

    test "registers a new device if not found" do
      payload = %{"keyData" => @valid_key_data, "deviceInfo" => @valid_device_info}
      assert {:ok, %Device{}} = DeviceHelper.find_or_register_device(payload)
    end
  end

  describe "find_by_device_id/1" do
    test "finds a device by device_id" do
      device = %Device{
        device_id: @valid_key_data["deviceId"],
        device_info: @valid_device_info,
        public_key_sign: @valid_key_data["pubkey"],
        public_key_dh: @valid_key_data["dhpubkey"]
      }
      Repo.insert!(device)

      assert %Device{} = DeviceHelper.find_by_device_id(@valid_key_data["deviceId"])
    end

    test "returns nil if device not found" do
      assert nil == DeviceHelper.find_by_device_id("non_existent_device_id")
    end
  end
end
