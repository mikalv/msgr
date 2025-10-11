defmodule Messngr.AIConversationTest do
  use Messngr.DataCase

  import Mox

  alias Messngr.{Accounts, Chat}

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    {:ok, account_a} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, account_b} = Accounts.create_account(%{"display_name" => "Ola"})

    profile_a = List.first(account_a.profiles)
    profile_b = List.first(account_b.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei Ola"})
    {:ok, _} = Chat.send_message(conversation.id, profile_b.id, %{"body" => "Hei Kari"})

    {:ok,
     %{
       account: account_a,
       profile: profile_a,
       other_profile: profile_b,
       conversation: conversation
     }}
  end

  test "conversation_reply/4 includes participant names in history", %{account: account, profile: profile, other_profile: other, conversation: conversation} do
    expect(Messngr.AI.LlmClientMock, :chat_completion, fn team_id, messages, opts ->
      assert team_id == account.id
      assert is_list(messages)
      assert [%{role: "system", content: system_prompt} | history] = messages
      assert String.contains?(system_prompt, profile.name)
      assert Enum.any?(history, fn entry -> entry.content =~ "[#{profile.name}]" end)
      assert Enum.any?(history, fn entry -> entry.content =~ "[#{other.name}]" end)
      assert Keyword.get(opts, :temperature) == 0.3
      {:ok, %{"choices" => []}}
    end)

    assert {:ok, %{"choices" => []}} =
             Messngr.ai_conversation_reply(account.id, conversation.id, profile,
               history_limit: "5",
               temperature: 0.3
             )
  end
end
