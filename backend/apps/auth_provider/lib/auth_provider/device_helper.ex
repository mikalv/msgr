defmodule AuthProvider.DeviceHelper do
  alias AuthProvider.Account.Device
  alias AuthProvider.Repo
  require Logger


  def validate_device_signature(%{"keyData" => keyData} = _payload) do
    signature = Base.decode64!(keyData["signature"])
    public_key = Base.decode64!(keyData["pubkey"])
    :crypto.verify(:eddsa, :sha512, keyData["deviceId"], signature, [public_key, :ed25519])
  end

  def register_device(%{"keyData" => keyData, "deviceInfo" => deviceInfo} = payload) do
    attrs = %{
      device_info: deviceInfo,
      device_id: keyData["deviceId"],
      public_key_sign: keyData["pubkey"],
      public_key_dh: keyData["dhpubkey"],
      metadata: metadata_from_payload(payload)
    }
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert
  end

  def find_or_register_device(%{"keyData" => keyData} = payload) do
    case Repo.get_by(Device, device_id: keyData["deviceId"]) do
      nil -> register_device(payload)
      %Device{} = device ->
        attrs =
          %{}
          |> maybe_put(:device_info, Map.get(payload, "deviceInfo"))
          |> maybe_put(:metadata, merge_metadata(device.metadata, Map.get(payload, "appInfo")))

        if map_size(attrs) == 0 do
          {:ok, device}
        else
          device
          |> Device.changeset(attrs)
          |> Repo.update()
        end
    end
  end

  def upsert_device_context(device_id, device_info, app_info) do
    case Repo.get_by(Device, device_id: device_id) do
      nil ->
        {:error, :not_found}

      %Device{} = device ->
        attrs =
          %{}
          |> maybe_put(:device_info, device_info)
          |> maybe_put(:metadata, merge_metadata(device.metadata, app_info))

        device
        |> Device.changeset(attrs)
        |> Repo.update()
    end
  end

  def find_by_device_id(did), do: Repo.get_by(Device, device_id: did)

  defp metadata_from_payload(payload) do
    app_info = Map.get(payload, "appInfo")
    merge_metadata(%{}, app_info, DateTime.utc_now())
  end

  defp merge_metadata(existing, app_info) do
    merge_metadata(existing, app_info, DateTime.utc_now())
  end

  defp merge_metadata(existing, app_info, timestamp) do
    base_metadata = existing || %{}
    with_last_seen =
      Map.put(base_metadata, "last_seen_at", DateTime.to_iso8601(timestamp))

    cond do
      is_map(app_info) and map_size(app_info) > 0 ->
        Map.put(with_last_seen, "app_info", app_info)

      true ->
        with_last_seen
    end
  end

  defp maybe_put(attrs, _key, value) when value in [nil, %{}], do: attrs
  defp maybe_put(attrs, key, value) when is_map(value), do: Map.put(attrs, key, value)
  defp maybe_put(attrs, _key, _value), do: attrs
end
