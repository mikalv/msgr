defmodule Messngr.Chat.Message do
  @moduledoc """
  Chat messages knyttet til en conversation. For nå lagrer vi ren tekst og en
  enkel status.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :body, :string
    field :status, Ecto.Enum, values: [:sending, :sent, :delivered, :read], default: :sent
    field :sent_at, :utc_datetime

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :status, :conversation_id, :profile_id, :sent_at])
    |> validate_required([:body, :conversation_id, :profile_id])
    |> validate_length(:body, min: 1, max: 4000)
  end
end
