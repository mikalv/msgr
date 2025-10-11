defmodule Teams.TenantTeam do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  schema "tenant_teams" do
    field :name, :string
    field :description, :string
    field :metadata, :map
    field :creator_uid, :string
    field :members, {:array, :string}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant_team, attrs) do
    tenant_team
    |> cast(attrs, [:name, :description, :creator_uid, :members, :metadata])
    |> validate_required([:name, :creator_uid])
    |> unique_constraint(:name)
  end

  @spec append_members(String.t(), list(String.t())) :: %__MODULE__{}
  def append_members(tenant, new_members) when is_list(new_members) and is_binary(tenant) do
    t = get_team!(tenant)
    members = t.members ++ new_members
    Logger.info "Appending new members to tenant=#{t.name}, new_members=#{inspect new_members}"
    t
      |> changeset(%{members: members})
      |> Teams.Repo.update()
  end

  @spec append_members(%__MODULE__{}, list(String.t())) :: %__MODULE__{}
  def append_members(%__MODULE__{} = tenant, new_members) when is_list(new_members) do
    members = tenant.members ++ new_members
    Logger.info "Appending new members to tenant=#{tenant.name}, new_members=#{inspect new_members}"
    tenant
      |> changeset(%{members: members})
      |> Teams.Repo.update()
  end

  @spec am_i_a_member?(String.t(), String.t()) :: {true, %__MODULE__{}} | {false, nil}
  def am_i_a_member?(tenant, uid) do
    q = from(tt in __MODULE__, where: ^uid in tt.members and tt.name == ^tenant)
    case Teams.Repo.one(q) do
      nil ->
        {false, nil}
      tenant ->
        {true, tenant}
    end
  end

  @spec my_teams(String.t()) :: list(%__MODULE__{})
  def my_teams(uid) do
    from(tt in __MODULE__, where: ^uid in tt.members) |> Teams.Repo.all()
  end

  @spec create_tenant(String.t(), String.t(), String.t()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t}
  def create_tenant(name, creator_uid, description \\ "") do
    %__MODULE__{}
      |> changeset(%{name: name, creator_uid: creator_uid, description: description, members: [creator_uid]})
      |> Teams.Repo.insert
  end

  @spec list() :: list(%__MODULE__{})
  def list(), do: Teams.Repo.all(__MODULE__)

  @spec list_names() :: list(String.t())
  def list_names(), do: Teams.Repo.all(from t in __MODULE__, select: t.name)

  @spec get_team!(String.t()) :: %__MODULE__{}
  def get_team!(name), do: Teams.Repo.get_by!(__MODULE__, name: name)
end
