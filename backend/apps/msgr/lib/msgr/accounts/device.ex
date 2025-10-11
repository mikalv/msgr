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
      :attesters,
      :last_handshake_at,
      :enabled
    ])
    |> validate_required([:account_id, :device_public_key])
    |> validate_length(:device_public_key, min: 8)
    |> normalize_attesters()
    |> unique_constraint(:device_public_key,
      name: :account_devices_account_id_device_public_key_index
    )
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:profile_id)
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
