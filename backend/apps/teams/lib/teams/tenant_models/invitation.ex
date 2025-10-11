defmodule Teams.TenantModels.Invitation do
  use Teams.Schema
  import Ecto.Changeset
  alias Teams.TenantModels.Profile

  schema "invitations" do
    field :is_used, :boolean
    field :msisdn, :string
    field :email, :string
    field :profile_id, :string

    field :metadata, :map
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:is_used, :msisdn, :email, :profile_id, :metadata])
  end

  def create_email_invitation(tenant, %Profile{} = profile, email) do
    metadata = %{"creator_profile_id" => profile.id}
    params = %{ "email" => email, "metadata" => metadata }
    create(tenant, params)
  end

  def create_msisdn_invitation(tenant, %Profile{} = profile, msisdn) do
    metadata = %{"creator_profile_id" => profile.id}
    params = %{ "msisdn" => msisdn, "metadata" => metadata }
    create(tenant, params)
  end

  # Query functions

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
