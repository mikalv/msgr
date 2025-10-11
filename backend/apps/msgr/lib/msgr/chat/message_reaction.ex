defmodule Messngr.Chat.MessageReaction do
  @moduledoc """
  Stores a single emoji reaction on a message.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "message_reactions" do
    field :emoji, :string
    field :metadata, :map, default: %{}

    belongs_to :message, Messngr.Chat.Message
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :metadata, :message_id, :profile_id])
    |> validate_required([:emoji, :message_id, :profile_id])
    |> validate_length(:emoji, min: 1, max: 32)
    |> put_default_metadata()
    |> unique_constraint([:message_id, :profile_id, :emoji],
      name: :message_reactions_unique_reaction
    )
  end

  defp put_default_metadata(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      %{} = metadata -> put_change(changeset, :metadata, metadata)
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
