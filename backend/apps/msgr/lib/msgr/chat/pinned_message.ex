defmodule Messngr.Chat.PinnedMessage do
  @moduledoc """
  Represents a pinned message within a conversation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pinned_messages" do
    field :pinned_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :message, Messngr.Chat.Message
    belongs_to :pinned_by, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pinned_message, attrs) do
    pinned_message
    |> cast(attrs, [
      :conversation_id,
      :message_id,
      :pinned_by_id,
      :pinned_at,
      :metadata
    ])
    |> validate_required([:conversation_id, :message_id, :pinned_by_id, :pinned_at])
    |> put_default_metadata()
    |> unique_constraint([:conversation_id, :message_id])
  end

  defp put_default_metadata(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      %{} = metadata -> put_change(changeset, :metadata, metadata)
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
