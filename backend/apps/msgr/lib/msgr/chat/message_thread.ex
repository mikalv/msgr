defmodule Messngr.Chat.MessageThread do
  @moduledoc """
  Represents a thread anchored to a root message inside a conversation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "message_threads" do
    field :metadata, :map, default: %{}
    field :last_activity_at, :utc_datetime

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :root_message, Messngr.Chat.Message
    belongs_to :created_by, Messngr.Accounts.Profile

    has_many :messages, Messngr.Chat.Message, foreign_key: :thread_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [
      :conversation_id,
      :root_message_id,
      :created_by_id,
      :metadata,
      :last_activity_at
    ])
    |> validate_required([:conversation_id, :root_message_id, :created_by_id])
    |> put_default_metadata()
    |> unique_constraint(:root_message_id)
  end

  defp put_default_metadata(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      %{} = metadata -> put_change(changeset, :metadata, metadata)
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
