defmodule Messngr.Notifications.DevicePushToken do
  @moduledoc """
  Device specific push token with metadata used to drive delivery policy.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.{Account, Device, Profile}

  @platforms [:ios, :android, :web]
  @statuses [:active, :revoked, :disabled]
  @modes [:private, :work, :family]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_push_tokens" do
    field :platform, Ecto.Enum, values: @platforms
    field :token, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :last_registered_at, :utc_datetime
    field :metadata, :map, default: %{}
    field :mode, Ecto.Enum, values: @modes, default: :private

    belongs_to :device, Device
    belongs_to :profile, Profile
    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :device_id,
      :profile_id,
      :account_id,
      :platform,
      :token,
      :status,
      :last_registered_at,
      :metadata,
      :mode
    ])
    |> validate_required([
      :device_id,
      :profile_id,
      :account_id,
      :platform,
      :token,
      :status,
      :last_registered_at,
      :mode
    ])
    |> update_change(:token, &String.trim/1)
    |> unique_constraint(:token, name: :device_push_tokens_device_platform_index)
    |> foreign_key_constraint(:device_id)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:account_id)
  end
end
