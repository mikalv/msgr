defmodule Messngr.Accounts.Contact do
  @moduledoc """
  Represents an imported contact tied to an account/profile. Contacts can be
  matched mot identiteter basert på e-post eller telefonnummer.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :name, :string
    field :email, :string
    field :phone_number, :string
    field :labels, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    belongs_to :account, Messngr.Accounts.Account
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :phone_number, :labels, :metadata, :account_id, :profile_id])
    |> validate_required([:name, :account_id])
    |> validate_length(:name, min: 2, max: 160)
    |> normalize_email()
    |> normalize_phone_number()
    |> put_default_metadata()
    |> unique_constraint(:email, name: :contacts_account_id_email_index)
    |> unique_constraint(:phone_number, name: :contacts_account_id_phone_number_index)
  end

  defp normalize_email(changeset) do
    case get_change(changeset, :email) || get_field(changeset, :email) do
      nil -> changeset
      "" -> put_change(changeset, :email, nil)
      email ->
        normalized = email |> String.trim() |> String.downcase()
        put_change(changeset, :email, normalized)
    end
  end

  defp normalize_phone_number(changeset) do
    case get_change(changeset, :phone_number) || get_field(changeset, :phone_number) do
      nil -> changeset
      "" -> put_change(changeset, :phone_number, nil)
      phone ->
        normalized = phone |> String.replace(~r/\D+/, "")
        put_change(changeset, :phone_number, normalized)
    end
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
