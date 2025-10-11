defmodule Messngr.Chat.Conversation do
  @moduledoc """
  Represents a chat between profiles. For MVP we focus on én-til-én, men
  strukturen støtter grupper.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :topic, :string
    field :kind, Ecto.Enum, values: [:direct, :group], default: :direct

    has_many :participants, Messngr.Chat.Participant
    has_many :messages, Messngr.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:topic, :kind])
    |> validate_required([:kind])
  end
end
