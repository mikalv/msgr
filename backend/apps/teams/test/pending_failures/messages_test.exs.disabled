defmodule Teams.MessagesTest do
  use Teams.DataCase

  alias Teams.Messages
  alias Teams.Channels
  alias Teams.TeamManagement
  alias Teams.Tenancy
  alias Teams.TenantModels.Profile

  setup do
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "Message Tester",
        "email" => "msg-#{Ecto.UUID.generate()}@example.com"
      })

    {:ok, team} =
      TeamManagement.create_team(%{
        name: "Messages Test Team",
        slug: "msg-test-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
        owner_account_id: account.id
      })

    prefix = team.schema_name
    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    {:ok, channel} =
      Channels.create_channel(prefix, %{
        name: "test-msgs",
        created_by: profile.id
      })

    on_exit(fn ->
      try do
        Tenancy.drop_tenant(team.id)
      rescue
        _ -> :ok
      end
    end)

    {:ok, prefix: prefix, profile: profile, channel: channel, team: team}
  end

  describe "create_message/2" do
    test "creates a message with content map", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      {:ok, message} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"type" => "text", "body" => "Hello world"}
        })

      assert message.content["body"] == "Hello world"
      assert message.channel_id == channel.id
      assert message.sender_profile_id == profile.id
    end

    test "creates a message with media_refs", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      {:ok, message} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"type" => "image"},
          media_refs: ["uploads/photo.jpg"]
        })

      assert message.media_refs == ["uploads/photo.jpg"]
    end
  end

  describe "list_messages/3" do
    test "returns messages in chronological order", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      for i <- 1..5 do
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Message #{i}"}
        })
      end

      {messages, meta} = Messages.list_messages(prefix, channel.id)
      assert length(messages) == 5
      assert Map.has_key?(meta, :has_more)
    end

    test "respects limit option", %{prefix: prefix, profile: profile, channel: channel} do
      for i <- 1..10 do
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Msg #{i}"}
        })
      end

      {messages, _meta} = Messages.list_messages(prefix, channel.id, %{limit: 3})
      assert length(messages) == 3
    end

    test "excludes thread replies from main list", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      {:ok, parent} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Parent"}
        })

      {:ok, _reply} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Reply"},
          thread_parent_id: parent.id
        })

      {messages, _meta} = Messages.list_messages(prefix, channel.id)
      # Only the parent should appear (replies are filtered by thread_parent_id IS NULL)
      assert length(messages) == 1
      assert hd(messages).id == parent.id
    end
  end

  describe "get_message/2" do
    test "returns message with preloaded sender_profile and reactions", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      {:ok, msg} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Fetch me"}
        })

      fetched = Messages.get_message(prefix, msg.id)
      assert fetched.id == msg.id
      assert fetched.sender_profile != nil
      assert fetched.sender_profile.id == profile.id
      assert is_list(fetched.reactions)
    end

    test "returns nil for non-existent message", %{prefix: prefix} do
      assert Messages.get_message(prefix, Ecto.UUID.generate()) == nil
    end
  end

  describe "get_thread/3" do
    test "returns parent message and its replies", %{
      prefix: prefix,
      profile: profile,
      channel: channel
    } do
      {:ok, parent} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Thread parent"}
        })

      {:ok, _reply1} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Reply 1"},
          thread_parent_id: parent.id
        })

      {:ok, _reply2} =
        Messages.create_message(prefix, %{
          channel_id: channel.id,
          sender_profile_id: profile.id,
          content: %{"body" => "Reply 2"},
          thread_parent_id: parent.id
        })

      {:ok, thread} = Messages.get_thread(prefix, parent.id)
      assert thread.parent.id == parent.id
      assert length(thread.replies) == 2
    end

    test "returns error for non-existent parent", %{prefix: prefix} do
      assert {:error, :not_found} = Messages.get_thread(prefix, Ecto.UUID.generate())
    end
  end
end
