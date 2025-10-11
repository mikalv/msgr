defmodule Messngr.Family.Family do
  @moduledoc """
  Familie-gruppe representasjon med navn, slug og tidsone.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Messngr.Family.{Event, Membership}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "families" do
    field :name, :string
    field :slug, :string
    field :time_zone, :string, default: "Etc/UTC"

    has_many :memberships, Membership
    has_many :events, Event

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(family, attrs) do
    family
    |> cast(attrs, [:name, :slug, :time_zone])
    |> validate_required([:name, :slug, :time_zone])
    |> update_change(:slug, &normalize_slug/1)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9\-]*$/, message: "must contain only lowercase letters, numbers and dashes")
    |> unique_constraint(:slug)
  end

  defp normalize_slug(nil), do: nil
  defp normalize_slug(slug), do: slug |> String.trim() |> String.downcase()
end
