defmodule Teams.TenantModels.ChannelMembership do
  @moduledoc """
  Tenant-scoped join between channels and profiles.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  @foreign_key_type :binary_id

  schema "channel_memberships" do
    belongs_to :channel, Teams.TenantModels.Channel, primary_key: true
    belongs_to :profile, Teams.TenantModels.Profile, primary_key: true

    field :role, :string, default: "member"
    field :joined_at, :utc_datetime
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:channel_id, :profile_id, :role, :joined_at])
    |> validate_required([:channel_id, :profile_id])
    |> validate_inclusion(:role, ~w(admin member))
    |> unique_constraint([:channel_id, :profile_id], name: :channel_memberships_pkey)
  end

  # Query helpers

  def members_of(prefix, channel_id) do
    from(cm in __MODULE__,
      where: cm.channel_id == ^channel_id,
      preload: [:profile]
    )
    |> Teams.Repo.all(prefix: prefix)
  end

  def channels_for(prefix, profile_id) do
    from(cm in __MODULE__,
      where: cm.profile_id == ^profile_id,
      preload: [:channel]
    )
    |> Teams.Repo.all(prefix: prefix)
  end

  def join(prefix, attrs) do
    %__MODULE__{}
    |> changeset(Map.put_new(attrs, :joined_at, DateTime.utc_now()))
    |> Teams.Repo.insert(prefix: prefix)
  end

  def leave(prefix, channel_id, profile_id) do
    from(cm in __MODULE__,
      where: cm.channel_id == ^channel_id and cm.profile_id == ^profile_id
    )
    |> Teams.Repo.delete_all(prefix: prefix)
  end
end
