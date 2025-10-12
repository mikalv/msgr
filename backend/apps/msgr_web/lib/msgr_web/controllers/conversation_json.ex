defmodule MessngrWeb.ConversationJSON do
  alias Messngr.Chat.{Conversation, Message}
  alias Messngr.Accounts.Profile
  alias MessngrWeb.MessageJSON

  def show(%{conversation: conversation}) do
    %{data: conversation(conversation)}
  end

  def index(%{page: %{entries: entries, meta: meta}}) do
    %{data: Enum.map(entries, &conversation/1), meta: encode_meta(meta)}
  end

  def watchers(%{payload: payload}) do
    %{data: %{watchers: payload.watchers, count: payload.count}}
  end

  defp conversation(%Conversation{} = conversation) do
    %{
      id: conversation.id,
      kind: conversation.kind,
      topic: conversation.topic,
      structure_type: conversation.structure_type,
      visibility: conversation.visibility,
      read_receipts_enabled: conversation.read_receipts_enabled,
      participants: Enum.map(conversation.participants, &participant/1),
      unread_count: conversation.unread_count || 0,
      last_message: encode_last_message(conversation.last_message)
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

  defp encode_last_message(%Message{} = message) do
    MessageJSON.show(%{message: message})[:data]
  end

  defp encode_last_message(_), do: nil

  defp encode_meta(nil), do: %{start_cursor: nil, end_cursor: nil, has_more: %{before: false, after: false}}

  defp encode_meta(meta) when is_map(meta) do
    %{
      start_cursor: Map.get(meta, :start_cursor),
      end_cursor: Map.get(meta, :end_cursor),
      has_more: %{
        before: get_in(meta, [:has_more, :before]) || false,
        after: get_in(meta, [:has_more, :after]) || false
      }
    }
  end
end
