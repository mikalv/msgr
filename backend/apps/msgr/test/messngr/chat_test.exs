defmodule Messngr.ChatTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat}

  setup do
    {:ok, account_a} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, account_b} = Accounts.create_account(%{"display_name" => "Ola"})

    profile_a = List.first(account_a.profiles)
    profile_b = List.first(account_b.profiles)

    {:ok, %{profile_a: profile_a, profile_b: profile_b}}
  end

  test "ensure_direct_conversation/2 creates conversation", %{profile_a: profile_a, profile_b: profile_b} do
    assert {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)
    assert conversation.kind == :direct
    assert Enum.count(conversation.participants) == 2
  end

  test "send_message/3 persists message", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    assert {:ok, message} =
             Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

    assert message.body == "Hei"
    assert message.profile.id == profile_a.id

    messages = Chat.list_messages(conversation.id)
    assert Enum.map(messages, & &1.body) == ["Hei"]
  end

  test "list_messages/2 respects limit", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    for body <- ["1", "2", "3"] do
      {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => body})
    end

    assert [%{body: "2"}, %{body: "3"}] = Chat.list_messages(conversation.id, limit: 2)
  end
end
