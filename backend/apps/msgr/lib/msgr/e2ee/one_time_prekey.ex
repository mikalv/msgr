defmodule Messngr.E2ee.OneTimePrekey do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "e2ee_one_time_prekeys" do
    field :opk_id, :integer
    field :public_key, :binary
    field :used_at, :utc_datetime

    belongs_to :device_key, Messngr.E2ee.DeviceKey

    timestamps(type: :utc_datetime)
  end

  def changeset(opk, attrs) do
    opk
    |> cast(attrs, [:device_key_id, :opk_id, :public_key, :used_at])
    |> validate_required([:device_key_id, :opk_id, :public_key])
    |> unique_constraint([:device_key_id, :opk_id])
    |> foreign_key_constraint(:device_key_id)
  end
end
