defmodule Teams.TenantModels.Draft do
  @moduledoc """
  Tenant-scoped draft per channel per profile.
  Drafts are permanent — never auto-deleted.
  Composite PK: (channel_id, profile_id).
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  @foreign_key_type :binary_id

  schema "drafts" do
    belongs_to :channel, Teams.TenantModels.Channel, primary_key: true
    belongs_to :profile, Teams.TenantModels.Profile, primary_key: true

    field :content, :map, default: %{}
    field :updated_at, :utc_datetime
  end

  @doc false
  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [:channel_id, :profile_id, :content, :updated_at])
    |> validate_required([:channel_id, :profile_id, :content])
    |> put_change(:updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> unique_constraint([:channel_id, :profile_id], name: :drafts_pkey)
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
      on_conflict: {:replace, [:content, :updated_at]},
      conflict_target: [:channel_id, :profile_id]
    )
  end

  def delete(prefix, channel_id, profile_id) do
    from(d in __MODULE__,
      where: d.channel_id == ^channel_id and d.profile_id == ^profile_id
    )
    |> Teams.Repo.delete_all(prefix: prefix)
  end

  def drafts_for_profile(prefix, profile_id) do
    from(d in __MODULE__, where: d.profile_id == ^profile_id)
    |> Teams.Repo.all(prefix: prefix)
  end
end
