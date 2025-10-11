defmodule AuthProvider.Account.UserDevice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "account_user_devices" do
    belongs_to :user, AuthProvider.Account.User
    belongs_to :device, AuthProvider.Account.Device
    timestamps()
  end


  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:user_id, :device_id])
    |> validate_required([:user_id, :device_id])
  end
end
