defmodule FamilySpace.ShoppingItem do
  @moduledoc """
  Individual entry within a shopping list.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shopping_list_items" do
    field :name, :string
    field :quantity, :string
    field :checked, :boolean, default: false

    belongs_to :list, FamilySpace.ShoppingList
    belongs_to :added_by, Profile, foreign_key: :added_by_profile_id
    belongs_to :checked_by, Profile, foreign_key: :checked_by_profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :list_id,
      :added_by_profile_id,
      :checked_by_profile_id,
      :name,
      :quantity,
      :checked
    ])
    |> validate_required([:list_id, :added_by_profile_id, :name])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_inclusion(:checked, [true, false])
    |> foreign_key_constraint(:list_id)
    |> foreign_key_constraint(:added_by_profile_id)
    |> foreign_key_constraint(:checked_by_profile_id)
  end
end
