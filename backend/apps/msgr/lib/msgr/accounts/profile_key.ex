defmodule Messngr.Accounts.ProfileKey do
  @moduledoc """
  Persisted key material scoped to a single profile.

  Keys are versioned and the encrypted payload contains the private component
  wrapped using the configured `encryption` metadata. The struct exposes helper
  functions for hashing fingerprints that can safely be synced to the client in
  order to decide whether new material should be downloaded.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type purpose :: :messaging | :signing | :backup

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_keys" do
    field :purpose, Ecto.Enum, values: [:messaging, :signing, :backup]
    field :public_key, :string
    field :fingerprint, :string
    field :encryption, :map, default: %{}
    field :encrypted_payload, :binary
    field :client_snapshot_version, :integer, default: 1
    field :metadata, :map, default: %{}
    field :rotated_at, :utc_datetime

    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile_key, attrs) do
    profile_key
    |> cast(attrs, [
      :profile_id,
      :purpose,
      :public_key,
      :fingerprint,
      :encryption,
      :encrypted_payload,
      :client_snapshot_version,
      :metadata,
      :rotated_at
    ])
    |> validate_required([:profile_id, :purpose, :public_key, :fingerprint, :encryption])
    |> validate_number(:client_snapshot_version, greater_than: 0)
    |> validate_encryption()
    |> put_default_encryption()
    |> unique_constraint(:purpose, name: :profile_keys_profile_purpose_index)
    |> foreign_key_constraint(:profile_id)
  end

  defp validate_encryption(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_encryption(%Ecto.Changeset{} = changeset) do
    case get_change(changeset, :encryption) || get_field(changeset, :encryption) do
      %{"mode" => mode} = encryption when is_binary(mode) ->
        changeset
        |> put_change(:encryption, stringify_keys(encryption))

      %{} = other ->
        add_error(changeset, :encryption, "must include mode", validation: {:mode, other})

      _ ->
        add_error(changeset, :encryption, "must be a map")
    end
  end

  defp put_default_encryption(%Ecto.Changeset{} = changeset) do
    update_change(changeset, :encryption, fn
      nil -> %{"mode" => "envelope", "cipher" => "aes-256-gcm"}
      value -> Map.put_new(value, "cipher", "aes-256-gcm")
    end)
  end

  defp stringify_keys(map) do
    for {key, value} <- map, into: %{} do
      {to_string(key), value}
    end
  end
end
