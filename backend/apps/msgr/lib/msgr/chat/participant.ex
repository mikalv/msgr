defmodule Messngr.Chat.Participant do
  @moduledoc """
  Connects en profil til en conversation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversation_participants" do
    field :role, Ecto.Enum, values: [:member, :owner], default: :member
    field :last_read_at, :utc_datetime

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :last_read_at, :conversation_id, :profile_id])
    |> validate_required([:conversation_id, :profile_id])
    |> unique_constraint([:conversation_id, :profile_id],
      name: :conversation_participants_conversation_id_profile_id_index
    )
  end
end
