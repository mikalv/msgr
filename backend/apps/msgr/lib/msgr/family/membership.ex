defmodule Messngr.Family.Membership do
  @moduledoc """
  Relasjon mellom profil og familie med rolle.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile
  alias Messngr.Family.Family

  @roles [:owner, :member]
  @type role :: :owner | :member

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "family_memberships" do
    field :role, Ecto.Enum, values: @roles, default: :member

    belongs_to :family, Family
    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:family_id, :profile_id, :role])
    |> validate_required([:family_id, :profile_id, :role])
    |> unique_constraint([:family_id, :profile_id])
  end

  def roles, do: @roles
end
