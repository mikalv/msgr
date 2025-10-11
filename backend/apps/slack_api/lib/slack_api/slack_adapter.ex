defmodule SlackApi.SlackAdapter do
  @moduledoc """
  Shapes internal Msgr structs into Slack-compatible maps.
  """

  alias Messngr.Accounts.{Account, Profile}
  alias Messngr.Chat.{Conversation, Message, Participant}
  alias SlackApi.{SlackId, SlackTimestamp}

  @spec conversation(Conversation.t(), keyword()) :: map()
  def conversation(%Conversation{} = conversation, opts \\ []) do
    account = Keyword.fetch!(opts, :account)

    %{
      id: SlackId.conversation(conversation),
      name: conversation_name(conversation),
      is_channel: conversation.kind == :channel,
      is_group: conversation.kind == :group,
      is_im: conversation.kind == :direct,
      is_private: conversation.visibility != :team,
      created: unix_timestamp(conversation.inserted_at),
      updated: unix_timestamp(conversation.updated_at || conversation.inserted_at),
      team_id: SlackId.team(account),
      num_members: length(conversation.participants || []),
      members: Enum.map(conversation.participants || [], &member_id/1),
      topic: topic_payload(conversation),
      purpose: purpose_payload(conversation),
      unread_count: conversation.unread_count || 0,
      unread_count_display: conversation.unread_count || 0,
      latest:
        conversation.last_message &&
          message(conversation.last_message, opts ++ [conversation: conversation])
    }
  end

  @spec message(Message.t(), keyword()) :: map()
  def message(%Message{} = message, opts \\ []) do
    account = Keyword.fetch!(opts, :account)
    conversation = Keyword.get(opts, :conversation)
    profile = message.profile || %Profile{id: message.profile_id, name: ""}
    sent_at = message.sent_at || message.inserted_at || DateTime.utc_now()

    %{
      type: "message",
      user: SlackId.profile(profile),
      text: message.body || Map.get(message.payload || %{}, "text") || "",
      ts: SlackTimestamp.encode(sent_at, message_id: message.id),
      team: SlackId.team(account),
      client_msg_id: message.id,
      channel: conversation && SlackId.conversation(conversation),
      blocks: [],
      attachments: [],
      metadata: message.metadata || %{},
      edited: edited_payload(message),
      deleted_at: deleted_payload(message),
      bot_id: nil
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @spec profile(Profile.t(), Account.t()) :: map()
  def profile(%Profile{} = profile, %Account{} = account) do
    %{
      id: SlackId.profile(profile),
      team_id: SlackId.team(account),
      name: profile.slug || profile.name,
      real_name: profile.name,
      display_name: profile.name,
      is_bot: false,
      is_app_user: false,
      profile: %{
        real_name: profile.name,
        display_name: profile.name,
        avatar_hash: nil,
        image_48: nil,
        image_72: nil,
        image_192: nil
      },
      updated: unix_timestamp(profile.updated_at || DateTime.utc_now()),
      presence: "active"
    }
  end

  defp conversation_name(%Conversation{topic: topic, kind: :direct}) when topic in [nil, ""] do
    "direct-message"
  end

  defp conversation_name(%Conversation{topic: topic}) when is_binary(topic) and topic != "" do
    topic
  end

  defp conversation_name(%Conversation{id: id}) do
    "channel-" <> Base.url_encode64(id, padding: false)
  end

  defp topic_payload(%Conversation{topic: topic}) do
    %{value: topic || "", creator: nil, last_set: 0}
  end

  defp purpose_payload(%Conversation{}) do
    %{value: "", creator: nil, last_set: 0}
  end

  defp member_id(%Participant{profile: %Profile{} = profile}), do: SlackId.profile(profile)

  defp member_id(%Participant{profile_id: profile_id}) when is_binary(profile_id),
    do: SlackId.profile(profile_id)

  defp unix_timestamp(nil), do: 0

  defp unix_timestamp(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :second)
  end

  defp edited_payload(%Message{edited_at: nil}), do: nil

  defp edited_payload(%Message{edited_at: edited_at, profile_id: profile_id}) do
    %{
      user: SlackId.profile(profile_id),
      ts: SlackTimestamp.encode(edited_at)
    }
  end

  defp deleted_payload(%Message{deleted_at: nil}), do: nil

  defp deleted_payload(%Message{deleted_at: deleted_at}) do
    SlackTimestamp.encode(deleted_at)
  end
end
