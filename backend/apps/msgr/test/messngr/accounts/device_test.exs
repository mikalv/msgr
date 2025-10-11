defmodule Messngr.Accounts.DeviceTest do
  use Messngr.DataCase

  alias Messngr.Accounts

  describe "devices" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Device Owner", "email" => "owner@example.com"})
      profile = List.first(account.profiles)

      {:ok, account: account, profile: profile}
    end

    test "create_device/1 persists Noise key and attesters", %{account: account, profile: profile} do
      {:ok, device} =
        Accounts.create_device(%{
          account_id: account.id,
          profile_id: profile.id,
          device_public_key: "noise1-abcdefghijk",
          attesters: [%{id: "server", signature: "abc"}]
        })

      assert device.account_id == account.id
      assert device.profile_id == profile.id
      assert device.enabled
      assert [%{"id" => "server", "signature" => "abc"}] =
               Enum.map(device.attesters, &normalize_keys/1)

      assert [device.id] == Enum.map(Accounts.list_devices(account.id), & &1.id)
    end

    test "activate_device/1 and deactivate_device/1 toggle enabled flag", %{account: account} do
      {:ok, device} =
        Accounts.create_device(%{
          account_id: account.id,
          device_public_key: "noise2-abcdefghijk"
        })

      {:ok, disabled} = Accounts.deactivate_device(device)
      refute disabled.enabled

      {:ok, reenabled} = Accounts.activate_device(disabled)
      assert reenabled.enabled
    end

    test "attach_device_for_identity/2 upserts and preloads account devices", _context do
      {:ok, identity} =
        Accounts.ensure_identity(%{
          kind: :email,
          value: "device-user@example.com",
          display_name: "Device User"
        })

      {:ok, %{identity: updated_identity, device: device}} =
        Accounts.attach_device_for_identity(identity, %{
          device_public_key: "noise-device-123",
          attesters: [%{id: "server"}]
        })

      assert device.device_public_key == "noise-device-123"
      assert device.account_id == updated_identity.account_id
      assert device.profile_id != nil
      assert Enum.any?(updated_identity.account.devices, &(&1.id == device.id))

      last_seen = device.last_handshake_at || DateTime.utc_now()

      {:ok, %{device: same_device}} =
        Accounts.attach_device_for_identity(updated_identity, %{
          device_public_key: "noise-device-123",
          last_handshake_at: DateTime.add(last_seen, 5, :second)
        })

      assert DateTime.compare(same_device.last_handshake_at, device.last_handshake_at) == :gt
    end

    test "create_device/1 enforces unique Noise key per account", %{account: account} do
      {:ok, _device} =
        Accounts.create_device(%{
          account_id: account.id,
          device_public_key: "noise-unique-1"
        })

      assert {:error, changeset} =
               Accounts.create_device(%{
                 account_id: account.id,
                 device_public_key: "noise-unique-1"
               })

      assert %{device_public_key: ["has already been taken"]} = errors_on(changeset)
    end
  end

  defp normalize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end
end
