defmodule MessngrWeb.ConversationChannelTest do
  use MessngrWeb.ChannelCase

  alias Ecto.UUID
  alias Messngr.{Accounts, Chat}
  alias MessngrWeb.{ConversationChannel, UserSocket}

  setup do
    {:ok, account_a} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, account_b} = Accounts.create_account(%{"display_name" => "Ola"})

    profile_a = List.first(account_a.profiles)
    profile_b = List.first(account_b.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok,
     account: account_a,
     profile: profile_a,
     peer_profile: profile_b,
     conversation: conversation}
  end

  test "join authorizes valid participants", %{account: account, profile: profile, conversation: conversation} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
        "account_id" => account.id,
        "profile_id" => profile.id
      })

    assert socket.assigns.conversation_id == conversation.id
    assert socket.assigns.current_profile.id == profile.id
  end

  test "join rejects unknown participants", %{conversation: conversation, account: account} do
    assert {:error, %{reason: "forbidden"}} =
             UserSocket
             |> socket("user_id", %{})
             |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
               "account_id" => account.id,
               "profile_id" => UUID.generate()
             })
  end

  test "push message:create persists and replies", %{account: account, profile: profile, conversation: conversation} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
        "account_id" => account.id,
        "profile_id" => profile.id
      })

    ref = push(socket, "message:create", %{"body" => "Hei på deg"})

    assert_reply ref, :ok, %{"data" => %{"body" => "Hei på deg", "id" => message_id}}
    assert_push "message_created", %{"data" => %{"body" => "Hei på deg", "id" => ^message_id}}
  end

  test "peer messages are broadcast to subscribers", %{account: account, profile: profile, peer_profile: peer_profile, conversation: conversation} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
        "account_id" => account.id,
        "profile_id" => profile.id
      })

    {:ok, message} = Chat.send_message(conversation.id, peer_profile.id, %{"body" => "Hei"})

    assert_push "message_created", %{"data" => %{"id" => message.id, "body" => "Hei"}}
  end

  test "message:sync replies with cursor data", %{account: account, profile: profile, conversation: conversation} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
        "account_id" => account.id,
        "profile_id" => profile.id
      })

    {:ok, _} = Chat.send_message(conversation.id, profile.id, %{"body" => "Hei"})

    ref = push(socket, "message:sync", %{"limit" => 1})

    assert_reply ref, :ok, %{
      "data" => [%{"body" => "Hei", "id" => message_id}],
      "meta" => %{"start_cursor" => ^message_id, "end_cursor" => ^message_id}
    }

    assert_push "message_backlog", %{"data" => [%{"body" => "Hei"}]}
  end

  test "conversation watcher events broadcast", %{account: account, profile: profile, conversation: conversation} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(ConversationChannel, "conversation:#{conversation.id}", %{
        "account_id" => account.id,
        "profile_id" => profile.id
      })

    ref = push(socket, "conversation:watch", %{})

    assert_reply ref, :ok, %{"data" => %{"count" => 1}}
    assert_push "conversation_watchers", %{"data" => %{"count" => 1}}

    ref_unwatch = push(socket, "conversation:unwatch", %{})
    assert_reply ref_unwatch, :ok, %{"data" => %{"count" => 0}}
    assert_push "conversation_watchers", %{"data" => %{"count" => 0}}
  end
end
