defmodule Messngr.Family.Event do
  @moduledoc """
  Hendelse i familiens delte kalender.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Accounts.Profile
  alias Messngr.Family.Family

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "family_events" do
    field :title, :string
    field :description, :string
    field :location, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :all_day, :boolean, default: false
    field :color, :string

    belongs_to :family, Family
    belongs_to :creator, Profile, foreign_key: :created_by_profile_id
    belongs_to :updated_by, Profile, foreign_key: :updated_by_profile_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :family_id,
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
    |> validate_required([:family_id, :created_by_profile_id, :title, :starts_at, :ends_at])
    |> validate_length(:title, max: 120)
    |> validate_ends_after_start()
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a hex color", allow_nil: true)
  end

  defp validate_ends_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    cond do
      is_nil(starts_at) or is_nil(ends_at) -> changeset
      DateTime.compare(ends_at, starts_at) in [:gt, :eq] -> changeset
      true -> add_error(changeset, :ends_at, "must be after start")
    end
  end
end
