defmodule Teams.TenantModels.Room do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Teams.TenantModels.Profile
  require Logger

  schema "rooms" do
    field :name, :string
    field :topic, :string
    field :description, :string
    field :members, {:array, :string}
    field :is_secret, :boolean
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:name, :topic, :description, :members, :is_secret, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  def create_room(tenant,
      %Profile{} = profile,
      %{"name" => _n, "description" => _d, "is_secret" => _i} = params,
      other_member_ids \\ []) do

    members = [profile.id] ++ other_member_ids
    metadata = %{"creator_profile_id" => profile.id}
    params = params
      |> Map.put("members", members)
      |> Map.put("metadata", metadata)
    create(tenant, params)
  end

  # Query functions

  def list_with_me(tenant, %Profile{} = profile) do
    liste1 = from(r in __MODULE__, where: "all" in r.members) |> Teams.Repo.all(prefix: Triplex.to_prefix(tenant))
    liste2 = from(r in __MODULE__, where: ^profile.id in r.members) |> Teams.Repo.all(prefix: Triplex.to_prefix(tenant))
    List.flatten(liste1, liste2)
  end

  def list(tenant) do
    Teams.Repo.all(__MODULE__, prefix: Triplex.to_prefix(tenant))
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
