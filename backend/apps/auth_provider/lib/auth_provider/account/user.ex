defmodule AuthProvider.Account.User do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @fields [:msisdn, :email, :metadata]
  @required_fields []

  schema "account_users" do
    field :metadata, :map
    field :email, :string
    field :uid, :string, source: :id
    field :msisdn, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, @fields)
    |> validate_format(:email, ~r/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    |> unique_constraint(:msisdn, message: "phone number already registered")
    |> unique_constraint(:email, message: "email already taken")
    |> validate_required(@required_fields)
  end

  def get_by_uid(uid), do: AuthProvider.Repo.get_by(__MODULE__, id: uid)
end
