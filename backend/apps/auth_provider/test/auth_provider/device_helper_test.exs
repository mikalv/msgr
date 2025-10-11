defmodule AuthProvider.DeviceHelperTest do
  use ExUnit.Case
  alias AuthProvider.DeviceHelper
  alias AuthProvider.Account.Device
  alias AuthProvider.Repo

  import Mock

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "validate_device_signature/1" do
    test "validates device signature correctly" do
      payload = %{"keyData" => %{"signature" => Base.encode64("signature"), "pubkey" => Base.encode64("public_key"), "deviceId" => "device_id"}}
      with_mock :crypto, [verify: fn _, _, _, _, _ -> true end] do
        assert DeviceHelper.validate_device_signature(payload)
      end
    end

    test "returns false for invalid signature" do
      payload = %{"keyData" => %{"signature" => Base.encode64("signature"), "pubkey" => Base.encode64("public_key"), "deviceId" => "device_id"}}
      with_mock :crypto, [verify: fn _, _, _, _, _ -> false end] do
        refute DeviceHelper.validate_device_signature(payload)
      end
    end
  end

  describe "register_device/1" do
    test "registers a new device" do
      payload = %{"keyData" => %{"deviceId" => "device_id", "pubkey" => "public_key", "dhpubkey" => "dh_public_key"}, "deviceInfo" => "device_info"}
      with_mock Repo, [insert: fn _ -> {:ok, %Device{id: 1, device_id: "device_id"}} end] do
        assert {:ok, %AuthProvider.Account.Device{__meta__: _, id: 1, metadata: nil, device_id: "device_id", public_key_sign: nil, public_key_dh: nil, device_info: nil, inserted_at: nil, updated_at: nil}} = DeviceHelper.register_device(payload)
      end
    end
  end

  describe "find_or_register_device/1" do
    test "registers a new device if not found" do
      payload = %{"keyData" => %{"deviceId" => "device_id", "pubkey" => "public_key", "dhpubkey" => "dh_public_key"}, "deviceInfo" => "device_info"}
      with_mock Repo, [get_by: fn _, _ -> nil end, insert: fn _ -> {:ok, %Device{id: 1, device_id: "device_id"}} end] do
        assert {:ok, %AuthProvider.Account.Device{__meta__: _, id: 1, metadata: nil, device_id: "device_id", public_key_sign: nil, public_key_dh: nil, device_info: nil, inserted_at: nil, updated_at: nil}} = DeviceHelper.find_or_register_device(payload)
      end
    end

    test "returns existing device if found" do
      payload = %{"keyData" => %{"deviceId" => "device_id", "pubkey" => "public_key", "dhpubkey" => "dh_public_key"}, "deviceInfo" => "device_info"}
      with_mock Repo, [get_by: fn _, _ -> %Device{id: 1, device_id: "device_id"} end] do
        assert {:ok, %AuthProvider.Account.Device{__meta__: _, id: 1, metadata: nil, device_id: "device_id", public_key_sign: nil, public_key_dh: nil, device_info: nil, inserted_at: nil, updated_at: nil}} = DeviceHelper.find_or_register_device(payload)
      end
    end
  end

  describe "find_by_device_id/1" do
    test "finds device by device_id" do
      with_mock Repo, [get_by: fn _, _ -> %Device{id: 1, device_id: "device_id"} end] do
        assert %AuthProvider.Account.Device{__meta__: _, id: 1, metadata: nil, device_id: "device_id", public_key_sign: nil, public_key_dh: nil, device_info: nil, inserted_at: nil, updated_at: nil} = DeviceHelper.find_by_device_id("device_id")
      end
    end
  end
end
