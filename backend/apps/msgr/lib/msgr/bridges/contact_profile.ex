defmodule Messngr.Bridges.ContactProfile do
  @moduledoc """
  Represents an aggregated person across bridge contacts and local Msgr records.

  Contact profiles collect matchable keys (email, phone, usernames, etc.) so that
  the client can present a unified conversation list even when the data originates
  from multiple bridge services or native Msgr contacts.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Bridges.{Contact, ContactProfileKey, ProfileLink}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_contact_profiles" do
    field :canonical_name, :string
    field :metadata, :map, default: %{}

    has_many :contacts, Contact
    has_many :keys, ContactProfileKey
    has_many :links, ProfileLink

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:canonical_name, :metadata])
    |> validate_length(:canonical_name, max: 200)
    |> put_default_metadata()
  end

  defp put_default_metadata(changeset) do
    case get_field(changeset, :metadata) do
      %{} -> changeset
      nil -> put_change(changeset, :metadata, %{})
      other when is_map(other) -> changeset
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
