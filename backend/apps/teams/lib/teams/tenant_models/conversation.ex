defmodule Teams.TenantModels.Conversation do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger
  alias Teams.TenantModels.Profile

  schema "conversations" do
    field :topic, :string
    field :is_secret, :boolean
    field :members, {:array, :string}
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:topic, :is_secret, :members, :metadata])
    |> validate_required([:members])
  end

  def create_conversation(tenant,
      %Profile{} = profile,
      %{"name" => _n, "description" => _d} = params,
      other_member_ids \\ []) do

    members = [profile.id] ++ other_member_ids
    if length(members) <= 1 do
      Logger.error "Profile #{inspect profile} attempted to create conversation with to little members. Members: #{inspect members}"
      {:error, "Can't create a conversation with one or less members."}
    else
      metadata = %{"creator_profile_id" => profile.id}
      params = params
        |> Map.put("members", members)
        |> Map.put("metadata", metadata)
      create(tenant, params)
    end
  end

  def get_by_id(tenant, id), do: Teams.Repo.get_by(__MODULE__, [id: id], prefix: Triplex.to_prefix(tenant))

  # Query functions

  def list_with_me(tenant, %Profile{} = profile) do
    from(r in __MODULE__, where: ^profile.id in r.members) |> Teams.Repo.all(prefix: Triplex.to_prefix(tenant))
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
