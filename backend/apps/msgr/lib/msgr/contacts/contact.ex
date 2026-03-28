defmodule Messngr.Contacts.Contact do
  @moduledoc """
  Represents a contact owned by an account.
  Uses URI-based identity model for cross-bridge contact resolution.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :display_name, :string
    field :notes, :string
    # Legacy fields kept for backward compatibility
    field :name, :string
    field :email, :string
    field :phone_number, :string
    field :labels, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    belongs_to :owner_account, Messngr.Accounts.Account, foreign_key: :owner_account_id
    belongs_to :account, Messngr.Accounts.Account
    belongs_to :profile, Messngr.Accounts.Profile

    has_many :identities, Messngr.Contacts.ContactIdentity, foreign_key: :contact_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :display_name,
      :notes,
      :name,
      :email,
      :phone_number,
      :labels,
      :metadata,
      :owner_account_id,
      :account_id,
      :profile_id
    ])
    |> validate_required([:owner_account_id])
  end
end
