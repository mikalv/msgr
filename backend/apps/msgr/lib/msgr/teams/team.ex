defmodule Messngr.Teams.Team do
  @moduledoc """
  Represents a team (workspace) in the public schema.
  Each team owns a tenant PostgreSQL schema for isolated data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field :name, :string
    field :slug, :string
    field :schema_name, :string
    field :domain, :string
    field :settings, :map, default: %{}

    belongs_to :owner_account, Messngr.Accounts.Account, foreign_key: :owner_account_id

    has_many :memberships, Messngr.Teams.TeamMembership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :slug, :schema_name, :domain, :owner_account_id, :settings])
    |> validate_required([:name, :slug, :schema_name])
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/,
      message: "must be lowercase alphanumeric with dashes"
    )
    |> validate_length(:slug, min: 2, max: 48)
    |> unique_constraint(:slug)
    |> unique_constraint(:schema_name)
    |> unique_constraint(:domain)
  end
end
