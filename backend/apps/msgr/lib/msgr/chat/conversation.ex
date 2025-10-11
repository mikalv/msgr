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
    field :kind, Ecto.Enum, values: [:direct, :group, :channel], default: :direct
    field :structure_type, Ecto.Enum,
      values: [:family, :business, :friends, :project, :other],
      default: nil

    field :visibility, Ecto.Enum, values: [:private, :team], default: :private
    field :unread_count, :integer, virtual: true, default: 0
    field :last_message, :map, virtual: true

    has_many :participants, Messngr.Chat.Participant
    has_many :messages, Messngr.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:topic, :kind, :structure_type, :visibility])
    |> validate_required([:kind, :visibility])
    |> maybe_require_topic()
    |> maybe_require_structure_type()
  end

  defp maybe_require_topic(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :kind) do
      kind when kind in [:group, :channel] ->
        changeset
        |> validate_required([:topic])
        |> validate_length(:topic, min: 3, max: 160)

      _ ->
        changeset
    end
  end

  defp maybe_require_structure_type(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :kind) do
      :direct -> changeset
      _ -> validate_required(changeset, [:structure_type])
    end
  end
end
