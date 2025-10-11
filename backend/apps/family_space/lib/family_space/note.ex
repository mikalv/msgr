defmodule FamilySpace.Note do
  @moduledoc """
  Rich text notes that belong to a collaborative space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "space_notes" do
    field :title, :string
    field :body, :string
    field :color, :string
    field :pinned, :boolean, default: false

    belongs_to :space, FamilySpace.Space
    belongs_to :created_by, Profile, foreign_key: :created_by_profile_id
    belongs_to :updated_by, Profile, foreign_key: :updated_by_profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [
      :space_id,
      :created_by_profile_id,
      :updated_by_profile_id,
      :title,
      :body,
      :color,
      :pinned
    ])
    |> validate_required([:space_id, :created_by_profile_id, :title])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:color, max: 20)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:created_by_profile_id)
    |> foreign_key_constraint(:updated_by_profile_id)
  end
end
