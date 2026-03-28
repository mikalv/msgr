defmodule Teams.TenantModels.Profile do
  @moduledoc """
  Tenant-scoped profile. Each account gets one profile per team.
  The account_id references public.accounts (cross-schema).
  """

  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "profiles" do
    field :account_id, :binary_id
    field :display_name, :string
    field :avatar_url, :string
    field :email, :string
    field :phone, :string
    field :role, :string, default: "member"

    has_many :messages, Teams.TenantModels.Message, foreign_key: :sender_profile_id
    has_many :channel_memberships, Teams.TenantModels.ChannelMembership, foreign_key: :profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:account_id, :display_name, :avatar_url, :email, :phone, :role])
    |> validate_required_unless_bot(attrs)
    |> validate_inclusion(:role, ~w(owner admin member bot))
    |> unique_constraint(:account_id)
  end

  # Bot profiles don't need account_id
  defp validate_required_unless_bot(changeset, attrs) do
    role = Map.get(attrs, :role) || Map.get(attrs, "role")

    if role == "bot" do
      changeset
    else
      validate_required(changeset, [:account_id])
    end
  end

  # Query helpers

  def get_by_id(prefix, id) do
    Teams.Repo.get(__MODULE__, id, prefix: prefix)
  end

  def get_by_account_id(prefix, account_id) do
    Teams.Repo.get_by(__MODULE__, [account_id: account_id], prefix: prefix)
  end

  def list(prefix) do
    Teams.Repo.all(__MODULE__, prefix: prefix)
  end

  def create(prefix, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(prefix: prefix)
  end

  def update(prefix, %__MODULE__{} = profile, attrs) do
    profile
    |> changeset(attrs)
    |> Teams.Repo.update(prefix: prefix)
  end

  def delete(prefix, %__MODULE__{} = profile) do
    Teams.Repo.delete(profile, prefix: prefix)
  end
end
