defmodule Messngr.Teams.TeamMembership do
  @moduledoc """
  Join table between accounts and teams in the public schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "team_memberships" do
    belongs_to :account, Messngr.Accounts.Account, primary_key: true
    belongs_to :team, Messngr.Teams.Team, primary_key: true

    field :role, :string, default: "member"
    field :joined_at, :utc_datetime
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:account_id, :team_id, :role, :joined_at])
    |> validate_required([:account_id, :team_id])
    |> validate_inclusion(:role, ~w(owner admin member))
    |> unique_constraint([:account_id, :team_id], name: :team_memberships_pkey)
  end
end
