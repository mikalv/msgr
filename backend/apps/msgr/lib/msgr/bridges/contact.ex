defmodule Messngr.Bridges.Contact do
  @moduledoc """
  Contact entry synchronised from an external chat service via a bridge.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Bridges.BridgeAccount

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_contacts" do
    field :external_id, :string
    field :display_name, :string
    field :handle, :string
    field :metadata, :map, default: %{}

    belongs_to :bridge_account, BridgeAccount

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:bridge_account_id, :external_id, :display_name, :handle, :metadata])
    |> validate_required([:bridge_account_id, :external_id])
    |> validate_change(:metadata, &ensure_map/2)
  end

  defp ensure_map(_field, value) when is_map(value), do: []
  defp ensure_map(field, value), do: [{field, {"must be a map", [kind: :map, value: value]}}]
end
