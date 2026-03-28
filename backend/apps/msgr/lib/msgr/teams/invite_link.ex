defmodule Messngr.Teams.InviteLink do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Messngr.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @default_ttl_days 7
  @code_length 8
  @code_alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  schema "invite_links" do
    field :code, :string
    field :expires_at, :utc_datetime
    field :used_count, :integer, default: 0
    field :revoked, :boolean, default: false

    belongs_to :team, Messngr.Teams.Team
    belongs_to :created_by_account, Messngr.Accounts.Account, foreign_key: :created_by_account_id

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:team_id, :created_by_account_id, :code, :expires_at, :revoked, :used_count])
    |> validate_required([:team_id, :created_by_account_id, :code, :expires_at])
    |> unique_constraint(:code)
  end

  @doc "Create a new invite link for a team."
  def create(team_id, account_id) do
    attrs = %{
      team_id: team_id,
      created_by_account_id: account_id,
      code: generate_code(),
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(@default_ttl_days * 86400, :second)
        |> DateTime.truncate(:second)
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc "Find a valid (non-expired, non-revoked) invite link by code."
  def get_valid_by_code(code) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([l], l.code == ^code and l.revoked == false and l.expires_at > ^now)
    |> Repo.one()
    |> Repo.preload(:team)
  end

  @doc "List active invite links for a team."
  def list_active(team_id) do
    now = DateTime.utc_now()

    __MODULE__
    |> where([l], l.team_id == ^team_id and l.revoked == false and l.expires_at > ^now)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
  end

  @doc "Revoke an invite link."
  def revoke(id) do
    case Repo.get(__MODULE__, id) do
      nil -> {:error, :not_found}
      link -> link |> changeset(%{revoked: true}) |> Repo.update()
    end
  end

  @doc "Increment the used_count after a successful join."
  def increment_used_count(link) do
    from(l in __MODULE__, where: l.id == ^link.id)
    |> Repo.update_all(inc: [used_count: 1])
  end

  defp generate_code do
    alphabet = String.graphemes(@code_alphabet)

    1..@code_length
    |> Enum.map(fn _ -> Enum.random(alphabet) end)
    |> Enum.join()
  end
end
