defmodule MessngrWeb.ConversationChannelTest do
  use MessngrWeb.ChannelCase

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
     peer_account: account_b,
     peer_profile: profile_b,
     conversation: conversation}
  end

  test "join authorizes valid participants", %{account: account, profile: profile, conversation: conversation} do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})

    assert socket.assigns.conversation_id == conversation.id
    assert socket.assigns.current_profile.id == profile.id
  end

  test "join rejects unknown participants", %{conversation: conversation} do
    {:ok, outsider} = Accounts.create_account(%{"display_name" => "Ukjent"})
    outsider_profile = hd(outsider.profiles)

    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(outsider, outsider_profile)

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})
  end

  test "push message:create persists and replies", %{account: account, profile: profile, conversation: conversation} do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})

    ref = push(socket, "message:create", %{"body" => "Hei på deg"})

    assert_reply ref, :ok, %{"data" => %{"body" => "Hei på deg", "id" => message_id}}
    assert_push "message_created", %{"data" => %{"body" => "Hei på deg", "id" => ^message_id}}
  end

  test "message:create rejects oversize payloads", %{account: account, profile: profile, conversation: conversation} do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})

    long_body = String.duplicate("a", 4_001)
    ref = push(socket, "message:create", %{"body" => long_body})

    assert_reply ref, :error, %{"errors" => ["body is too long (max 4000 characters)"]}
  end

  test "message:create enforces per-profile rate limits", %{account: account, profile: profile, conversation: conversation} do
    original_limits = Application.get_env(:msgr, :rate_limits)
    updated_limits = Keyword.put(original_limits || [], :conversation_message_event, [limit: 1, period: 60_000])
    Application.put_env(:msgr, :rate_limits, updated_limits)

    on_exit(fn -> Application.put_env(:msgr, :rate_limits, original_limits) end)

    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})

    ref1 = push(socket, "message:create", %{"body" => "Hei"})
    assert_reply ref1, :ok, %{"data" => %{"body" => "Hei"}}

    ref2 = push(socket, "message:create", %{"body" => "Igjen"})
    assert_reply ref2, :error, %{"errors" => ["rate limit exceeded"]}
  end

  test "peer messages are broadcast to subscribers", %{account: account, profile: profile, peer_profile: peer_profile, conversation: conversation} do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})

    {:ok, message} = Chat.send_message(conversation.id, peer_profile.id, %{"body" => "Hei"})

    assert_push "message_created", %{"data" => %{"id" => message.id, "body" => "Hei"}}
  end

  describe "events" do
    setup %{account: account, profile: profile, peer_account: peer_account, peer_profile: peer_profile, conversation: conversation} do
      socket = join_conversation(account, profile, conversation)
      assert_push socket, "presence_state", state
      assert is_map(state)

      peer_socket = join_conversation(peer_account, peer_profile, conversation)
      assert_push peer_socket, "presence_state", peer_state
      assert is_map(peer_state)
      assert_push socket, "presence_diff", diff
      assert is_map(diff)

      {:ok, message} = Chat.send_message(conversation.id, profile.id, %{"body" => "Hei"})
      assert_push socket, "message_created", _
      assert_push peer_socket, "message_created", _

      {:ok, %{socket: socket, peer_socket: peer_socket, message: message, conversation: conversation, profile: profile}}
    end

    test "typing events broadcast to peers", %{socket: socket, peer_socket: peer_socket} do
      push(socket, "typing:start", %{})
      assert_push peer_socket, "typing_started", payload
      assert payload[:profile_id] == socket.assigns.current_profile.id
      assert payload[:expires_at]

      push(socket, "typing:stop", %{})
      assert_push peer_socket, "typing_stopped", stop_payload
      assert stop_payload[:profile_id] == socket.assigns.current_profile.id
    end

    test "reaction add/remove reply and broadcast", %{socket: socket, peer_socket: peer_socket, message: message, conversation: conversation, profile: profile} do
      ref = push(socket, "reaction:add", %{"message_id" => message.id, "emoji" => "🔥"})
      assert_reply ref, :ok, %{"reaction" => %{"emoji" => "🔥"}}
      assert_push peer_socket, "reaction_added", payload
      assert payload[:emoji] == "🔥"
      assert Enum.any?(payload[:aggregates], &(&1[:emoji] == "🔥" && &1[:count] == 1))

      ref_remove = push(socket, "reaction:remove", %{"message_id" => message.id, "emoji" => "🔥"})
      assert_reply ref_remove, :ok, %{"status" => "removed"}
      assert_push peer_socket, "reaction_removed", removed_payload
      assert removed_payload[:emoji] == "🔥"
    end

    test "message update broadcasts change", %{socket: socket, peer_socket: peer_socket, message: message} do
      ref = push(socket, "message:update", %{"message_id" => message.id, "body" => "Oppdatert"})
      assert_reply ref, :ok, %{"data" => %{"body" => "Oppdatert"}}
      assert_push peer_socket, "message_updated", %{"data" => %{"body" => "Oppdatert"}}
    end

    test "message delete broadcasts deletion", %{socket: socket, peer_socket: peer_socket, message: message} do
      ref = push(socket, "message:delete", %{"message_id" => message.id})
      assert_reply ref, :ok, %{"data" => %{"id" => message.id}}
      assert_push peer_socket, "message_deleted", %{:message_id => ^message.id, :deleted_at => deleted_at}
      assert is_binary(deleted_at)
    end

    test "message read acknowledges and notifies peers", %{peer_socket: peer_socket, socket: socket, message: message, conversation: conversation, profile: profile} do
      # Send a message from the peer so the main socket can mark it as read
      {:ok, inbound} = Chat.send_message(conversation.id, peer_socket.assigns.current_profile.id, %{"body" => "Ny"})
      assert_push socket, "message_created", _
      assert_push peer_socket, "message_created", _

      ref = push(socket, "message:read", %{"message_id" => inbound.id})
      assert_reply ref, :ok, %{"status" => "read"}
      assert_push peer_socket, "message_read", %{:profile_id => ^profile.id, :message_id => ^inbound.id, :read_at => read_at}
      assert is_binary(read_at)
    end

    test "pin and unpin broadcast", %{socket: socket, peer_socket: peer_socket, message: message} do
      ref = push(socket, "message:pin", %{"message_id" => message.id, "metadata" => %{"section" => "top"}})
      assert_reply ref, :ok, %{"pinned" => %{"metadata" => %{"section" => "top"}}}
      assert_push peer_socket, "message_pinned", %{:message_id => ^message.id, :metadata => %{"section" => "top"}}

      ref_unpin = push(socket, "message:unpin", %{"message_id" => message.id})
      assert_reply ref_unpin, :ok, %{"status" => "unpinned"}
      assert_push peer_socket, "message_unpinned", %{:message_id => ^message.id}
end

  defp join_conversation(account, profile, conversation) do
    {socket, _session} =
      UserSocket
      |> socket("user_id", %{})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, ConversationChannel, "conversation:#{conversation.id}", %{})
    socket
  end
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
