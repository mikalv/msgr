defmodule Messngr.Accounts.Device do
  @moduledoc """
  Represents a physical or virtual client that authenticates via static Noise keys
  and is associated with an account/profile.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_devices" do
    field :device_public_key, :string
    field :public_key_fingerprint, :string
    field :attesters, {:array, :map}, default: []
    field :last_handshake_at, :utc_datetime
    field :enabled, :boolean, default: true

    belongs_to :account, Messngr.Accounts.Account
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :account_id,
      :profile_id,
      :device_public_key,
      :public_key_fingerprint,
      :attesters,
      :last_handshake_at,
      :enabled
    ])
    |> update_change(:device_public_key, &normalize_key_input/1)
    |> validate_required([:account_id, :device_public_key])
    |> validate_device_key()
    |> normalize_attesters()
    |> unique_constraint(:device_public_key,
      name: :account_devices_account_id_device_public_key_index
    )
    |> unique_constraint(:public_key_fingerprint,
      name: :account_devices_account_id_public_key_fingerprint_index
    )
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:profile_id)
  end

  defp normalize_key_input(value) when is_binary(value), do: String.trim(value)
  defp normalize_key_input(value), do: value

  defp validate_device_key(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_device_key(%Ecto.Changeset{} = changeset) do
    case Ecto.Changeset.get_change(changeset, :device_public_key) do
      nil ->
        ensure_fingerprint_present(changeset)

      value ->
        case Messngr.Accounts.DeviceKey.normalize(value) do
          {:ok, encoded, raw} ->
            changeset
            |> Ecto.Changeset.put_change(:device_public_key, encoded)
            |> Ecto.Changeset.put_change(:public_key_fingerprint, Messngr.Accounts.DeviceKey.fingerprint(raw))

          {:error, :empty} ->
            Ecto.Changeset.add_error(changeset, :device_public_key, "can't be blank")

          {:error, _reason} ->
            Ecto.Changeset.add_error(
              changeset,
              :device_public_key,
              "must be a 32- or 64-byte Noise static key encoded as base64/base64url or hex"
            )
        end
    end
  end

  defp ensure_fingerprint_present(%Ecto.Changeset{} = changeset) do
    case {
           Ecto.Changeset.get_field(changeset, :device_public_key),
           Ecto.Changeset.get_field(changeset, :public_key_fingerprint)
         } do
      {key, nil} when is_binary(key) ->
        with {:ok, encoded, raw} <- Messngr.Accounts.DeviceKey.normalize(key) do
          changeset
          |> Ecto.Changeset.put_change(:device_public_key, encoded)
          |> Ecto.Changeset.put_change(:public_key_fingerprint, Messngr.Accounts.DeviceKey.fingerprint(raw))
        else
          {:error, _reason} ->
            Ecto.Changeset.add_error(
              changeset,
              :device_public_key,
              "must be a 32- or 64-byte Noise static key encoded as base64/base64url or hex"
            )
        end

      _ ->
        changeset
    end
  end

  defp normalize_attesters(changeset) do
    update_change(changeset, :attesters, fn value ->
      value
      |> case do
        nil -> []
        list when is_list(list) -> list
        other -> [other]
      end
      |> Enum.map(fn
        %{} = map -> map
        value -> %{value: to_string(value)}
      end)
    end)
  end
end
