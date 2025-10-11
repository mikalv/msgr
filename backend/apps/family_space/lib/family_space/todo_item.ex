defmodule FamilySpace.TodoItem do
  @moduledoc """
  Represents a task within a todo list.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type status :: :pending | :in_progress | :done
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "todo_items" do
    field :content, :string
    field :status, Ecto.Enum, values: [:pending, :in_progress, :done], default: :pending
    field :due_at, :utc_datetime

    belongs_to :list, FamilySpace.TodoList
    belongs_to :created_by, Profile, foreign_key: :created_by_profile_id
    belongs_to :assignee, Profile, foreign_key: :assignee_profile_id
    belongs_to :completed_by, Profile, foreign_key: :completed_by_profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :list_id,
      :created_by_profile_id,
      :assignee_profile_id,
      :completed_by_profile_id,
      :content,
      :status,
      :due_at
    ])
    |> validate_required([:list_id, :created_by_profile_id, :content, :status])
    |> validate_length(:content, min: 1, max: 500)
    |> foreign_key_constraint(:list_id)
    |> foreign_key_constraint(:created_by_profile_id)
    |> foreign_key_constraint(:assignee_profile_id)
    |> foreign_key_constraint(:completed_by_profile_id)
  end
end
