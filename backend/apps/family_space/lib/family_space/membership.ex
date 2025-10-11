defmodule FamilySpace.Membership do
  @moduledoc """
  Space membership linking a profile to a collaborative space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type role :: :owner | :admin | :member
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "space_memberships" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member

    belongs_to :space, FamilySpace.Space
    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:space_id, :profile_id, :role])
    |> validate_required([:space_id, :profile_id, :role])
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:profile_id)
    |> unique_constraint([:space_id, :profile_id])
  end
end
