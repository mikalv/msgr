defmodule Messngr.Bridges.ProfileLink do
  @moduledoc """
  Associates a contact profile with an external source reference.

  Sources can include native Msgr contacts, Msgr identities, or future bridge
  specific identifiers that do not correspond to a synchronised roster entry.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Bridges.ContactProfile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_contact_profile_links" do
    field :source, :string
    field :source_id, :string
    field :metadata, :map, default: %{}

    belongs_to :profile, ContactProfile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:profile_id, :source, :source_id, :metadata])
    |> validate_required([:profile_id, :source, :source_id])
    |> update_change(:source, &normalize_source/1)
    |> validate_length(:source, max: 64)
    |> validate_change(:metadata, &ensure_map/2)
  end

  defp normalize_source(source) when is_binary(source), do: source |> String.trim() |> String.downcase()
  defp normalize_source(source) when is_atom(source), do: source |> Atom.to_string() |> normalize_source()
  defp normalize_source(_), do: nil

  defp ensure_map(_field, value) when is_map(value), do: []
  defp ensure_map(field, value), do: [{field, {"must be a map", [kind: :map, value: value]}}]
end
