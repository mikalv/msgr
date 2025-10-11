defmodule FamilySpace.TodoList do
  @moduledoc """
  General purpose task lists for a collaborative space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type t :: %__MODULE__{}
  @type status :: :active | :archived

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "todo_lists" do
    field :name, :string
    field :status, Ecto.Enum, values: [:active, :archived], default: :active

    belongs_to :space, FamilySpace.Space
    belongs_to :created_by, Profile, foreign_key: :created_by_profile_id
    has_many :items, FamilySpace.TodoItem, preload_order: [asc: :inserted_at]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:space_id, :created_by_profile_id, :name, :status])
    |> validate_required([:space_id, :created_by_profile_id, :name, :status])
    |> validate_length(:name, min: 2, max: 140)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:created_by_profile_id)
  end
end
