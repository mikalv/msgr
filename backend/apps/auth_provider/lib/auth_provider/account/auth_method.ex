defmodule AuthProvider.Account.AuthMethod do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "account_auth_methods" do
    field :value, :string
    field :metadata, :map
    field :auth_type, :string
    field :is_disabled, :boolean, default: false
    belongs_to :user, AuthProvider.Account.User

    timestamps()
  end

  @doc false
  def changeset(auth_methods, attrs) do
    auth_methods
    |> cast(attrs, [:user_id, :auth_type, :value, :is_disabled, :metadata])
    |> validate_required([:user_id, :auth_type, :value, :is_disabled])
  end

  def get_current_auth_code_if_any_q(user_id) do
    from(am in __MODULE__, where: am.user_id == ^user_id
        and am.is_disabled == false
        and am.auth_type == "one_time_code")
  end
end
