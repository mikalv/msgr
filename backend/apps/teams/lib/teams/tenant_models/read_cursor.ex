defmodule Teams.TenantModels.ReadCursor do
  @moduledoc """
  Tenant-scoped read cursor tracking per channel per profile.
  Composite PK: (channel_id, profile_id).
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  @foreign_key_type :binary_id

  schema "read_cursors" do
    belongs_to :channel, Teams.TenantModels.Channel, primary_key: true
    belongs_to :profile, Teams.TenantModels.Profile, primary_key: true
    belongs_to :last_read_message, Teams.TenantModels.Message
  end

  @doc false
  def changeset(cursor, attrs) do
    cursor
    |> cast(attrs, [:channel_id, :profile_id, :last_read_message_id])
    |> validate_required([:channel_id, :profile_id])
    |> unique_constraint([:channel_id, :profile_id], name: :read_cursors_pkey)
  end

  def get(prefix, channel_id, profile_id) do
    Teams.Repo.get_by(
      __MODULE__,
      [channel_id: channel_id, profile_id: profile_id],
      prefix: prefix
    )
  end

  def upsert(prefix, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(
      prefix: prefix,
      on_conflict: {:replace, [:last_read_message_id]},
      conflict_target: [:channel_id, :profile_id]
    )
  end

  def cursors_for_profile(prefix, profile_id) do
    from(rc in __MODULE__, where: rc.profile_id == ^profile_id)
    |> Teams.Repo.all(prefix: prefix)
  end
end
