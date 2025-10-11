defmodule AuthProvider.DeviceHelper do
  alias AuthProvider.Account.Device
  alias AuthProvider.Repo
  require Logger


  def validate_device_signature(%{"keyData" => keyData} = _payload) do
    signature = Base.decode64!(keyData["signature"])
    public_key = Base.decode64!(keyData["pubkey"])
    :crypto.verify(:eddsa, :sha512, keyData["deviceId"], signature, [public_key, :ed25519])
  end

  def register_device(%{"keyData" => keyData, "deviceInfo" => deviceInfo} = _payload) do
    attrs = %{
      device_info: deviceInfo,
      device_id: keyData["deviceId"],
      public_key_sign: keyData["pubkey"],
      public_key_dh: keyData["dhpubkey"]
    }
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert
  end

  def find_or_register_device(%{"keyData" => keyData, "deviceInfo" => _deviceInfo} = payload) do
    case Repo.get_by(Device, device_id: keyData["deviceId"]) do
      nil -> register_device(payload)
      dev -> {:ok, dev}
    end
  end

  def find_by_device_id(did), do: Repo.get_by(Device, device_id: did)
end
