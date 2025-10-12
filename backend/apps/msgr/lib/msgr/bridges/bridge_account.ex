defmodule Messngr.Bridges.BridgeAccount do
  @moduledoc """
  Represents a per-account bridge identity for an external chat service.

  Stores the session material, reported capabilities, and metadata required to
  resume connections via bridge daemons. Associated contacts and channel
  memberships are stored in dedicated tables.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.Account
  alias Messngr.Bridges.{BridgeChannel, BridgeContact}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bridge_accounts" do
    field :service, :string
    field :external_id, :string
    field :display_name, :string
    field :session, :map, default: %{}
    field :capabilities, :map, default: %{}
    field :metadata, :map, default: %{}
    field :last_synced_at, :utc_datetime

    belongs_to :account, Account
    has_many :contacts, BridgeContact, preload_order: [asc: :display_name]
    has_many :channels, BridgeChannel, preload_order: [asc: :name]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :account_id,
      :service,
      :external_id,
      :display_name,
      :session,
      :capabilities,
      :metadata,
      :last_synced_at
    ])
    |> validate_required([:account_id, :service])
    |> update_change(:service, &String.downcase/1)
    |> validate_length(:service, min: 2, max: 32)
    |> validate_change(:session, &ensure_map/2)
    |> validate_change(:capabilities, &ensure_map/2)
    |> validate_change(:metadata, &ensure_map/2)
  end

  defp ensure_map(_field, value) when is_map(value), do: []

  defp ensure_map(field, value),
    do: [{field, {"must be a map", [kind: :map, value: value]}}]
end
