defmodule AuthProvider.Account.Device do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_devices" do
    field :metadata, :map
    field :device_id, :string
    field :public_key_sign, :string
    field :public_key_dh, :string
    field :device_info, :map

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:device_id, :public_key_sign, :public_key_dh, :device_info, :metadata])
    |> validate_required([:device_id, :public_key_sign, :public_key_dh])
    |> unique_constraint(:device_id)
  end
end
