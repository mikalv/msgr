defmodule Teams.TenantModels.Message do
  @moduledoc """
  Tenant-scoped message. Supports threads via thread_parent_id,
  rich content as JSONB map, and media_refs for attached files.
  """

  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "messages" do
    belongs_to :channel, Teams.TenantModels.Channel
    belongs_to :sender_profile, Teams.TenantModels.Profile
    belongs_to :thread_parent, __MODULE__

    field :content, :map, default: %{}
    field :media_refs, {:array, :string}, default: []
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime

    has_many :thread_replies, __MODULE__, foreign_key: :thread_parent_id
    has_many :reactions, Teams.TenantModels.Reaction, foreign_key: :message_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:channel_id, :sender_profile_id, :thread_parent_id, :content, :media_refs, :edited_at, :deleted_at])
    |> validate_required([:channel_id, :content])
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:sender_profile_id)
    |> foreign_key_constraint(:thread_parent_id)
  end

  # Query helpers

  def for_channel(prefix, channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    base =
      from(m in __MODULE__,
        where: m.channel_id == ^channel_id and is_nil(m.thread_parent_id) and is_nil(m.deleted_at),
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:sender_profile]
      )

    base =
      case Keyword.get(opts, :before) do
        nil -> base
        cursor -> from(m in base, where: m.inserted_at < ^cursor)
      end

    base =
      case Keyword.get(opts, :after) do
        nil -> base
        cursor -> from(m in base, where: m.inserted_at > ^cursor)
      end

    Teams.Repo.all(base, prefix: prefix)
  end

  def thread_replies(prefix, parent_id) do
    from(m in __MODULE__,
      where: m.thread_parent_id == ^parent_id,
      order_by: [asc: m.inserted_at],
      preload: [:sender_profile]
    )
    |> Teams.Repo.all(prefix: prefix)
  end

  def create(prefix, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(prefix: prefix)
  end

  def update_content(prefix, %__MODULE__{} = message, content) do
    message
    |> changeset(%{content: content, edited_at: DateTime.utc_now()})
    |> Teams.Repo.update(prefix: prefix)
  end

  def soft_delete(prefix, %__MODULE__{} = message) do
    message
    |> changeset(%{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
    |> Teams.Repo.update(prefix: prefix)
  end
end
