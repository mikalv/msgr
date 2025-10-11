defmodule FamilySpace.Space do
  @moduledoc """
  Represents a collaborative space that can be used by families or other groups.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "spaces" do
    field :name, :string
    field :slug, :string
    field :time_zone, :string, default: "Etc/UTC"
    field :kind, Ecto.Enum, values: [:family, :business, :custom], default: :family

    has_many :memberships, FamilySpace.Membership, preload_order: [asc: :inserted_at]
    has_many :events, FamilySpace.Event
    has_many :shopping_lists, FamilySpace.ShoppingList
    has_many :todo_lists, FamilySpace.TodoList

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(space, attrs) do
    space
    |> cast(attrs, [:name, :slug, :time_zone, :kind])
    |> validate_required([:name, :slug, :time_zone, :kind])
    |> validate_length(:name, min: 2, max: 140)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
  end
end
