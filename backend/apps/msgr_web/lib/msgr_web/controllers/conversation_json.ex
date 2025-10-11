defmodule MessngrWeb.ConversationJSON do
  alias Messngr.Chat.Conversation
  alias Messngr.Accounts.Profile

  def show(%{conversation: conversation}) do
    %{data: conversation(conversation)}
  end

  defp conversation(%Conversation{} = conversation) do
    %{
      id: conversation.id,
      kind: conversation.kind,
      topic: conversation.topic,
      structure_type: conversation.structure_type,
      visibility: conversation.visibility,
      participants: Enum.map(conversation.participants, &participant/1)
    }
  end

  defp participant(%{profile: %Profile{} = profile} = participant) do
    %{
      id: participant.id,
      profile: %{
        id: profile.id,
        name: profile.name,
        slug: profile.slug,
        mode: profile.mode
      },
      role: participant.role,
      last_read_at: participant.last_read_at
    }
  end
end
