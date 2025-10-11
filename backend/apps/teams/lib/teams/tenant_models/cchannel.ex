defmodule Teams.TenantModels.CChannel do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  schema "channels" do
    field :name, :string
    field :topic, :string
    field :description, :string
    field :members, {:array, :string}
    field :is_secret, :boolean
    field :channel_type, :string # "room" or "conversation"
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end
end
