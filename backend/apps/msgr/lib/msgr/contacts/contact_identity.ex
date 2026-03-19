defmodule Messngr.Contacts.ContactIdentity do
  @moduledoc """
  Represents a URI-based identity tied to a contact.
  Enables cross-bridge contact resolution (e.g. msgr://, tel:, mailto:).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contact_identities" do
    field :uri, :string
    field :canonical_uri, :string
    field :bridge_type, :string
    field :bridge_meta, :map, default: %{}
    field :is_primary, :boolean, default: false
    field :verified_at, :utc_datetime

    belongs_to :contact, Messngr.Contacts.Contact

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:contact_id, :uri, :canonical_uri, :bridge_type, :bridge_meta, :is_primary, :verified_at])
    |> validate_required([:contact_id])
    |> unique_constraint(:uri)
  end
end
