defmodule MessngrWeb.ConversationJSON do
  alias Messngr.Chat.Conversation
  alias Messngr.Accounts.Profile

  def index(%{page: %{entries: entries, meta: meta}}) do
    %{
      data: Enum.map(entries, &conversation_summary/1),
      meta: %{
        before_id: meta[:before_id],
        after_id: meta[:after_id],
        around_id: meta[:around_id],
        has_more: meta[:has_more]
      }
    }
  end

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

  defp conversation_summary(%{conversation: conversation, participant: participant} = entry) do
    conversation(conversation)
    |> Map.merge(%{
      unread_count: entry[:unread_count] || 0,
      participant: %{
        id: participant.id,
        last_read_at: participant.last_read_at,
        role: participant.role
      },
      last_message: last_message_payload(entry[:last_message])
    })
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

  defp last_message_payload(nil), do: nil

  defp last_message_payload(message) do
    %{
      id: message.id,
      type: message.kind |> to_string(),
      body: message.body,
      status: message.status,
      sent_at: message.sent_at,
      inserted_at: message.inserted_at,
      payload: message.payload || %{},
      profile:
        case message.profile do
          %Profile{} = profile ->
            %{
              id: profile.id,
              name: profile.name,
              mode: profile.mode
            }

          _ -> nil
        end
    }
  end
end
