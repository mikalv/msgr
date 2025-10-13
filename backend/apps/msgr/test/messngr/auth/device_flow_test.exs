defmodule Messngr.Auth.DeviceFlowTest do
  use Messngr.DataCase

  describe "OTP device registration" do
    test "verify_auth_challenge/3 upserts device using issued_for" do
      key = "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE"
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "otp-device@example.com",
          "device_id" => key
        })

      {:ok, %{account: account, identity: identity}} =
        Messngr.verify_auth_challenge(challenge.id, code, %{"display_name" => "OTP Device"})

      device = Enum.find(account.devices, &(&1.device_public_key == key))
      assert device
      assert device.enabled
      assert device.last_handshake_at
      assert identity.account.devices |> Enum.any?(&(&1.id == device.id))

      {:ok, challenge2, code2} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "otp-device@example.com",
          "device_id" => key
        })

      first_handshake = device.last_handshake_at

      {:ok, %{account: account2}} =
        Messngr.verify_auth_challenge(challenge2.id, code2, %{})

      device2 = Enum.find(account2.devices, &(&1.device_public_key == key))
      assert DateTime.compare(device2.last_handshake_at, first_handshake) != :lt
    end
  end

  describe "OIDC device registration" do
    test "complete_oidc/1 associates device by Noise key" do
      key = "AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI"
      {:ok, %{account: account}} =
        Messngr.complete_oidc(%{
          "provider" => "example",
          "subject" => "oidc-device-1",
          "email" => "oidc-device@example.com",
          "name" => "OIDC Device",
          "device_id" => key
        })

      assert [%{device_public_key: ^key}] =
               Enum.map(account.devices, &%{device_public_key: &1.device_public_key})

      {:ok, %{account: account2}} =
        Messngr.complete_oidc(%{
          "provider" => "example",
          "subject" => "oidc-device-1",
          "device_public_key" => key,
          "name" => "OIDC Device"
        })

      device = Enum.find(account2.devices, &(&1.device_public_key == key))
      assert device.last_handshake_at
    end
  end
end
