defmodule Teams.TenantModels.Message do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Teams.TenantModels.{Conversation, Profile, Room}
  alias Teams.Repo

  @derive {Jason.Encoder, only: [:msgid, :content, :is_system_msg, :room_id, :profile_id, :conversation_id, :in_reply_to_id, :inserted_at, :updated_at, :metadata]}
  schema "messages" do
    field :msgid, :string
    belongs_to :profile, Profile, [foreign_key: :profile_id, type: :binary_id]
    belongs_to :room, Room, [foreign_key: :room_id, type: :binary_id]
    belongs_to :conversation, Conversation, [foreign_key: :conversation_id, type: :binary_id]
    field :content, :string
    field :is_system_msg, :boolean
    field :in_reply_to_id, :integer
    field :metadata, :map

    belongs_to(:parent, __MODULE__, foreign_key: :id, references: :message_parent, define_field: false)
    has_many(:children, __MODULE__, foreign_key: :in_reply_to_id, references: :id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:msgid, :profile_id, :room_id, :conversation_id, :content, :is_system_msg, :in_reply_to_id, :metadata])
    |> cast_assoc(:room)
    |> cast_assoc(:conversation)
    |> cast_assoc(:profile)
    |> cast_assoc(:parent)
    |> cast_assoc(:children)
    |> validate_required([:content])
  end

  def create_conversation_message(tenant, conversation_id, sender_id, message, metadata \\ %{}) do
    next_id_seq = Ecto.Adapters.SQL.query!(
      Teams.Repo,
      "select pg_sequence_last_value('" <> Triplex.to_prefix(tenant) <> ".messages_id_seq') as nextID;", [])
        |> Map.from_struct
        |> Map.get(:rows)
        |> List.first
        |> List.first # Yes it's correct with two in a row. Value is stored like [[number]].
    %__MODULE__{}
    |> changeset(%{
        msgid: Teams.SecureID.id!(next_id_seq, "M"),
        conversation_id: conversation_id,
        profile_id: sender_id,
        content: message,
        metadata: metadata
      })
    |> Repo.insert(prefix: Triplex.to_prefix(tenant))
  end

  def create_room_message(tenant, room_id, sender_id, message, metadata \\ %{}) do
    next_id_seq = Ecto.Adapters.SQL.query!(
      Teams.Repo,
      "select pg_sequence_last_value('" <> Triplex.to_prefix(tenant) <> ".messages_id_seq') as nextID;", [])
        |> Map.from_struct
        |> Map.get(:rows)
        |> List.first
        |> List.first # Yes it's correct with two in a row. Value is stored like [[number]].
    %__MODULE__{}
    |> changeset(%{msgid: Teams.SecureID.id!(next_id_seq, "M"), room_id: room_id, profile_id: sender_id, content: message, metadata: metadata})
    |> Repo.insert!(prefix: Triplex.to_prefix(tenant))
    |> Repo.preload([:profile, :room, :conversation])
  end

  def create_system_message(tenant, room_id, message, metadata \\ %{}) do
    next_id_seq = Ecto.Adapters.SQL.query!(
      Teams.Repo,
      "select pg_sequence_last_value('" <> Triplex.to_prefix(tenant) <> ".messages_id_seq') as nextID;", [])
        |> Map.from_struct
        |> Map.get(:rows)
        |> List.first
        |> List.first # Yes it's correct with two in a row. Value is stored like [[number]].
    next_id_seq = if is_nil(next_id_seq), do: 1, else: next_id_seq
    %__MODULE__{}
    |> changeset(%{msgid: Teams.SecureID.id!(next_id_seq, "M"), room_id: room_id, content: message, is_system_msg: true, metadata: metadata})
    |> Repo.insert(prefix: Triplex.to_prefix(tenant))
  end

  def get_for_room(tenant, room_id) do
    from(m in __MODULE__, where: m.room_id == ^room_id) |> Repo.all(prefix: Triplex.to_prefix(tenant))
  end

  # Query functions

  def list(tenant) do
    Teams.Repo.all(__MODULE__, prefix: Triplex.to_prefix(tenant))
  end

  def create(tenant, attrs \\ %{}) do
    %__MODULE__{}
      |> changeset(attrs)
      |> Teams.Repo.insert(prefix: Triplex.to_prefix(tenant))
  end

  def update(tenant, obj, attrs) do
    obj
    |> changeset(attrs)
    |> Teams.Repo.update(prefix: Triplex.to_prefix(tenant))
  end

  def delete(tenant, obj) do
    obj
    |> Teams.Repo.delete(prefix: Triplex.to_prefix(tenant))
  end
end
