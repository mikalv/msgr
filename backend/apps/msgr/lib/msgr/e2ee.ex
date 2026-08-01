defmodule Messngr.E2ee do
  @moduledoc """
  Optional async key directory for personal-mode E2EE.

  Missing/empty bundles are a normal state — never a send blocker for clients.
  Cryptographic envelope contents are opaque to the server.
  """

  import Ecto.Query

  alias Messngr.E2ee.{DeviceKey, OneTimePrekey}
  alias Messngr.Repo

  @doc """
  Upsert device identity/signed-prekey and replace unused OPK batch.
  """
  def put_keys(profile_id, attrs) when is_binary(profile_id) and is_map(attrs) do
    device_id = Map.get(attrs, "device_id") || Map.get(attrs, :device_id)
    identity_key = decode_key(Map.get(attrs, "identity_key") || Map.get(attrs, :identity_key))
    signed_prekey = decode_key(Map.get(attrs, "signed_prekey") || Map.get(attrs, :signed_prekey))
    spk_id = Map.get(attrs, "spk_id") || Map.get(attrs, :spk_id)
    spk_signature = decode_key(Map.get(attrs, "spk_signature") || Map.get(attrs, :spk_signature))
    opks = Map.get(attrs, "one_time_prekeys") || Map.get(attrs, :one_time_prekeys) || []

    with {:ok, identity_key} <- identity_key,
         {:ok, signed_prekey} <- signed_prekey,
         {:ok, spk_signature} <- spk_signature,
         true <- is_binary(device_id) and device_id != "",
         true <- is_integer(spk_id) do
      Repo.transaction(fn ->
        device_key =
          case Repo.get_by(DeviceKey, profile_id: profile_id, device_id: device_id) do
            nil -> %DeviceKey{profile_id: profile_id, device_id: device_id}
            existing -> existing
          end

        changeset =
          DeviceKey.changeset(device_key, %{
            profile_id: profile_id,
            device_id: device_id,
            identity_key: identity_key,
            signed_prekey: signed_prekey,
            spk_id: spk_id,
            spk_signature: spk_signature
          })

        device_key =
          case Repo.insert_or_update(changeset) do
            {:ok, key} -> key
            {:error, changeset} -> Repo.rollback(changeset)
          end

        # Drop unused OPKs, then insert the new batch.
        from(o in OneTimePrekey,
          where: o.device_key_id == ^device_key.id and is_nil(o.used_at)
        )
        |> Repo.delete_all()

        Enum.each(opks, fn opk ->
          opk_id = Map.get(opk, "opk_id") || Map.get(opk, :opk_id)
          public_key = decode_key(Map.get(opk, "public_key") || Map.get(opk, :public_key))

          with true <- is_integer(opk_id),
               {:ok, public_key} <- public_key do
            %OneTimePrekey{}
            |> OneTimePrekey.changeset(%{
              device_key_id: device_key.id,
              opk_id: opk_id,
              public_key: public_key
            })
            |> Repo.insert!()
          else
            _ -> :ok
          end
        end)

        preload_count(device_key)
      end)
    else
      false -> {:error, :invalid_attrs}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns bundles for all devices on a profile. Pops one unused OPK per device when present.
  Empty list is success (not an error).
  """
  def fetch_bundles(profile_id) when is_binary(profile_id) do
    device_keys =
      from(d in DeviceKey,
        where: d.profile_id == ^profile_id,
        order_by: [asc: d.inserted_at]
      )
      |> Repo.all()

    bundles =
      Enum.map(device_keys, fn device_key ->
        opk =
          Repo.transaction(fn ->
            opk =
              from(o in OneTimePrekey,
                where: o.device_key_id == ^device_key.id and is_nil(o.used_at),
                order_by: [asc: o.opk_id],
                lock: "FOR UPDATE SKIP LOCKED",
                limit: 1
              )
              |> Repo.one()

            case opk do
              nil ->
                nil

              row ->
                {:ok, updated} =
                  row
                  |> OneTimePrekey.changeset(%{used_at: DateTime.utc_now() |> DateTime.truncate(:second)})
                  |> Repo.update()

                updated
            end
          end)
          |> case do
            {:ok, value} -> value
            _ -> nil
          end

        %{
          "device_id" => device_key.device_id,
          "identity_key" => Base.encode64(device_key.identity_key),
          "signed_prekey" => Base.encode64(device_key.signed_prekey),
          "spk_id" => device_key.spk_id,
          "spk_signature" => Base.encode64(device_key.spk_signature),
          "one_time_prekey" =>
            if(opk,
              do: %{
                "opk_id" => opk.opk_id,
                "public_key" => Base.encode64(opk.public_key)
              },
              else: nil
            )
        }
      end)

    {:ok, bundles}
  end

  def count_one_time_prekeys(profile_id, device_id)
      when is_binary(profile_id) and is_binary(device_id) do
    case Repo.get_by(DeviceKey, profile_id: profile_id, device_id: device_id) do
      nil ->
        {:ok, 0}

      device_key ->
        count =
          from(o in OneTimePrekey,
            where: o.device_key_id == ^device_key.id and is_nil(o.used_at),
            select: count(o.id)
          )
          |> Repo.one()

        {:ok, count}
    end
  end

  @doc """
  Device IDs known to the E2EE key directory for a profile (for rid:* targeting hints).
  """
  def list_device_ids_for_profile(profile_id) when is_binary(profile_id) do
    from(d in DeviceKey,
      where: d.profile_id == ^profile_id,
      select: d.device_id,
      order_by: [asc: d.device_id]
    )
    |> Repo.all()
  end

  defp preload_count(%DeviceKey{} = device_key) do
    count =
      from(o in OneTimePrekey,
        where: o.device_key_id == ^device_key.id and is_nil(o.used_at),
        select: count(o.id)
      )
      |> Repo.one()

    %{
      device_id: device_key.device_id,
      spk_id: device_key.spk_id,
      one_time_prekey_count: count
    }
  end

  defp decode_key(nil), do: {:error, :missing_key}
  defp decode_key(value) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, bytes} when byte_size(bytes) in [32, 64] -> {:ok, bytes}
      {:ok, _} -> {:error, :invalid_key_length}
      :error ->
        case Base.url_decode64(value, padding: false) do
          {:ok, bytes} when byte_size(bytes) in [32, 64] -> {:ok, bytes}
          _ -> {:error, :invalid_key_encoding}
        end
    end
  end

  defp decode_key(value) when is_list(value), do: {:ok, :erlang.list_to_binary(value)}
  defp decode_key(_), do: {:error, :invalid_key}
end
