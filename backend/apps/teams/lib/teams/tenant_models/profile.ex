defmodule Teams.TenantModels.Profile do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Teams.Repo

  schema "profiles" do
    field :uid, :string
    field :username, :string
    field :first_name, :string
    field :last_name, :string
    field :avatar_url, :string
    field :status, :string
    field :is_bot, :boolean
    field :settings, :map
    field :metadata, :map
    many_to_many(
      :roles,
      Teams.TenantModels.Role,
      join_through: Teams.TenantModels.ProfileRole,
      on_replace: :delete
    )
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:uid, :username, :first_name, :last_name, :avatar_url, :status, :settings, :metadata])
    |> validate_required([:username])
    |> unique_constraint(:uid)
    |> unique_constraint(:username)
  end

  def changeset_update_roles(%__MODULE__{} = model, roles) do
    model
    |> cast(%{}, [:username])
    |> put_assoc(:roles, roles)
  end

  def quick_create_profile(tenant_team_name, uid, username, first_name \\ "", last_name \\ "") do
    new = changeset(%__MODULE__{}, %{uid: uid, username: username, first_name: first_name, last_name: last_name})
    Repo.insert!(new, prefix: Triplex.to_prefix(tenant_team_name))
  end

  def load_roles(tenant, %__MODULE__{} = profile), do: Repo.preload(profile, [:roles], prefix: Triplex.to_prefix(tenant))

  def can?(tenant, %__MODULE__{} = profile, what) do
    whats =
      Map.get(Map.from_struct(profile), :roles)
        |> Enum.map(fn x -> x.permissions end)
        |> List.flatten

    (what in whats)
  end

  # Query functions

  def count(tenant) do
    query = from p in __MODULE__, select: count("id")
    Repo.one(query, [prefix: Triplex.to_prefix(tenant)])
  end

  def get_by_id(tenant, id), do: Repo.get(__MODULE__, id, prefix: Triplex.to_prefix(tenant)) |> Repo.preload([:roles], prefix: Triplex.to_prefix(tenant))
  def get_by_uid(tenant, uid), do: Repo.get_by(__MODULE__, [uid: uid], prefix: Triplex.to_prefix(tenant)) |> Repo.preload([:roles], prefix: Triplex.to_prefix(tenant))

  def list(tenant) do
    Teams.Repo.all(__MODULE__, prefix: Triplex.to_prefix(tenant)) |> Enum.map(fn x -> Repo.preload(x, [:roles], prefix: Triplex.to_prefix(tenant)) end)
  end

  def create(tenant, attrs \\ %{}) do
    %__MODULE__{}
      |> changeset(attrs)
      |> Teams.Repo.insert(prefix: Triplex.to_prefix(tenant))
  end

  def update(tenant, obj, attrs) do
    obj
    |> changeset(attrs)
    |> Teams.Repo.update(prefix: Triplex.to_prefix(tenant))
  end

  def delete(tenant, obj) do
    obj
    |> Teams.Repo.delete(prefix: Triplex.to_prefix(tenant))
  end
end
