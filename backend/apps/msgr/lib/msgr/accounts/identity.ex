defmodule Messngr.Accounts.Identity do
  @moduledoc """
  Represents a credential or login mechanism tied to an account. Supports
  passwordless email/phone and federated OIDC identities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_identities" do
    field :kind, Ecto.Enum, values: [:email, :phone, :oidc]
    field :value, :string
    field :provider, :string
    field :subject, :string
    field :verified_at, :utc_datetime
    field :last_challenged_at, :utc_datetime

    belongs_to :account, Messngr.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:account_id, :kind, :value, :provider, :subject, :verified_at, :last_challenged_at])
    |> validate_required([:account_id, :kind])
    |> validate_value_presence()
    |> unique_constraint(:value, name: :account_identities_account_id_kind_value_index)
    |> unique_constraint(:provider_subject, name: :account_identities_provider_subject_index)
  end

  defp validate_value_presence(%{changes: %{kind: :oidc}} = changeset) do
    changeset
    |> validate_required([:provider, :subject])
  end

  defp validate_value_presence(%{changes: %{kind: kind}} = changeset)
       when kind in [:email, :phone] do
    changeset
    |> validate_required([:value])
  end

  defp validate_value_presence(changeset), do: changeset
end

