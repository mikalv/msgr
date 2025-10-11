defmodule FamilySpace.Event do
  @moduledoc """
  Calendar event attached to a collaborative space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "space_events" do
    field :title, :string
    field :description, :string
    field :location, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :all_day, :boolean, default: false
    field :color, :string

    belongs_to :space, FamilySpace.Space
    belongs_to :creator, Profile, foreign_key: :created_by_profile_id
    belongs_to :updated_by, Profile, foreign_key: :updated_by_profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :space_id,
      :created_by_profile_id,
      :updated_by_profile_id,
      :title,
      :description,
      :location,
      :starts_at,
      :ends_at,
      :all_day,
      :color
    ])
    |> validate_required([
      :space_id,
      :created_by_profile_id,
      :updated_by_profile_id,
      :title,
      :starts_at,
      :ends_at
    ])
    |> validate_length(:title, min: 1, max: 140)
    |> validate_inclusion(:all_day, [true, false])
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:created_by_profile_id)
    |> foreign_key_constraint(:updated_by_profile_id)
  end
end
