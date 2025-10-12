defmodule Messngr.Bridges.Channel do
  @moduledoc """
  Channel or group membership synchronised from an external chat service.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Bridges.BridgeAccount

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_channels" do
    field :external_id, :string
    field :name, :string
    field :kind, :string, default: "chat"
    field :topic, :string
    field :role, :string
    field :muted, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :bridge_account, BridgeAccount

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :bridge_account_id,
      :external_id,
      :name,
      :kind,
      :topic,
      :role,
      :muted,
      :metadata
    ])
    |> validate_required([:bridge_account_id, :external_id, :kind])
    |> validate_change(:metadata, &ensure_map/2)
  end

  defp ensure_map(_field, value) when is_map(value), do: []
  defp ensure_map(field, value), do: [{field, {"must be a map", [kind: :map, value: value]}}]
end
