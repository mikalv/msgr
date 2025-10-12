defmodule Messngr.Bridges.ContactProfileKey do
  @moduledoc """
  Stores the deduplication keys associated with a contact profile.

  Keys allow us to match bridge contacts and native Msgr contacts using emails,
  phone numbers, usernames, bridge specific identifiers, and other metadata.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Bridges.ContactProfile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_contact_profile_keys" do
    field :kind, :string
    field :value, :string
    field :confidence, :integer, default: 1

    belongs_to :profile, ContactProfile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(key, attrs) do
    key
    |> cast(attrs, [:profile_id, :kind, :value, :confidence])
    |> validate_required([:profile_id, :kind, :value])
    |> update_change(:kind, &normalize_kind/1)
    |> update_change(:value, &normalize_value/1)
    |> validate_number(:confidence, greater_than: 0, less_than_or_equal_to: 100)
  end

  defp normalize_kind(kind) when is_binary(kind), do: kind |> String.trim() |> String.downcase()
  defp normalize_kind(kind) when is_atom(kind), do: kind |> Atom.to_string() |> normalize_kind()
  defp normalize_kind(_), do: nil

  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_value(_), do: nil
end
