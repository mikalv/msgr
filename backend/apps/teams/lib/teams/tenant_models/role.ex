defmodule Teams.TenantModels.Role do
  use Teams.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name, :id]}
  schema "roles" do
    field :name, :string
    field :permissions, {:array, :string}
    field :is_default, :boolean
    field :metadata, :map
    many_to_many(
      :profiles,
      Teams.TenantModels.Profile,
      join_through: Teams.TenantModels.ProfileRole,
      on_replace: :delete
    )
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:name, :permissions, :is_default, :metadata])
    |> validate_required([:name, :permissions])
    |> unique_constraint(:name)
  end

  # Query functions

  def get_default(tenant), do: Teams.Repo.get_by(__MODULE__, [is_default: true], prefix: Triplex.to_prefix(tenant))

  def get_by_name(tenant, name), do: Teams.Repo.get_by(__MODULE__, [name: name], prefix: Triplex.to_prefix(tenant))

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
