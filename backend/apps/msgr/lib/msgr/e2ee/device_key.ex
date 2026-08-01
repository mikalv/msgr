defmodule Messngr.E2ee.DeviceKey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "e2ee_device_keys" do
    field :device_id, :string
    field :identity_key, :binary
    field :signed_prekey, :binary
    field :spk_id, :integer
    field :spk_signature, :binary

    belongs_to :profile, Messngr.Accounts.Profile
    has_many :one_time_prekeys, Messngr.E2ee.OneTimePrekey, foreign_key: :device_key_id

    timestamps(type: :utc_datetime)
  end

  def changeset(device_key, attrs) do
    device_key
    |> cast(attrs, [
      :profile_id,
      :device_id,
      :identity_key,
      :signed_prekey,
      :spk_id,
      :spk_signature
    ])
    |> validate_required([
      :profile_id,
      :device_id,
      :identity_key,
      :signed_prekey,
      :spk_id,
      :spk_signature
    ])
    |> validate_length(:device_id, min: 1, max: 128)
    |> unique_constraint([:profile_id, :device_id])
    |> foreign_key_constraint(:profile_id)
  end
end
