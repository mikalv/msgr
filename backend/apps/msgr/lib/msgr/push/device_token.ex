defmodule Messngr.Push.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_push_tokens" do
    field :token, :string
    field :platform, :string, default: "apns"
    field :device_name, :string
    field :enabled, :boolean, default: true
    belongs_to :account, Messngr.Accounts.Account
    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:account_id, :token, :platform, :device_name, :enabled])
    |> validate_required([:account_id, :token, :platform])
    |> unique_constraint([:account_id, :token])
  end
end
