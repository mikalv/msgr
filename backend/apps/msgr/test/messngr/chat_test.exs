defmodule Messngr.ChatTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat, Media, Repo}
  alias Messngr.Media.Upload

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
    assert conversation.visibility == :private
    assert conversation.structure_type == nil
    assert Enum.count(conversation.participants) == 2
  end

  test "create_group_conversation/3 creates group with owner", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, account_c} = Accounts.create_account(%{"display_name" => "Per"})
    profile_c = List.first(account_c.profiles)

    assert {:ok, conversation} =
             Chat.create_group_conversation(profile_a.id, [profile_b.id, profile_c.id], %{
               "topic" => "Plan",
               "structure_type" => "family"
             })

    assert conversation.kind == :group
    assert conversation.topic == "Plan"
    assert conversation.structure_type == :family
    assert conversation.visibility == :private
    assert Enum.count(conversation.participants) == 3

    owner = Enum.find(conversation.participants, &(&1.role == :owner))
    assert owner.profile.id == profile_a.id
  end

  test "create_channel_conversation/2 creates channel with members", %{profile_a: profile_a, profile_b: profile_b} do
    assert {:ok, conversation} =
             Chat.create_channel_conversation(profile_a.id, %{
               "topic" => "Announcements",
               "participant_ids" => [profile_b.id]
             })

    assert conversation.kind == :channel
    assert conversation.topic == "Announcements"
    assert conversation.structure_type == :project
    assert conversation.visibility == :team
    assert Enum.any?(conversation.participants, &(&1.role == :member && &1.profile.id == profile_b.id))
  end

  test "create_channel_conversation/2 supports private visibility", %{profile_a: profile_a, profile_b: profile_b} do
    assert {:ok, conversation} =
             Chat.create_channel_conversation(profile_a.id, %{
               "topic" => "Secret",
               "participant_ids" => [profile_b.id],
               "visibility" => "private",
               "structure_type" => "business"
             })

    assert conversation.visibility == :private
    assert conversation.structure_type == :business
  end

  test "create_group_conversation/3 defaults structure type when missing", %{profile_a: profile_a, profile_b: profile_b} do
    assert {:ok, conversation} =
             Chat.create_group_conversation(profile_a.id, [profile_b.id], %{"topic" => "Afterwork"})

    assert conversation.structure_type == :friends
  end

  test "create_channel_conversation/2 requires topic", %{profile_a: profile_a} do
    assert {:error, %Ecto.Changeset{}} = Chat.create_channel_conversation(profile_a.id, %{})
  end

  test "send_message/3 persists message", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    assert {:ok, message} =
             Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

    assert message.body == "Hei"
    assert message.kind == :text
    assert message.profile.id == profile_a.id

    page = Chat.list_messages(conversation.id)
    assert Enum.map(page.entries, & &1.body) == ["Hei"]
    assert page.meta.has_more == %{before: false, after: false}
  end

  test "list_messages/2 respects limit", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    for body <- ["1", "2", "3"] do
      {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => body})
    end

    page = Chat.list_messages(conversation.id, limit: 2)
    assert Enum.map(page.entries, & &1.body) == ["2", "3"]
    assert page.meta.has_more.before
    refute page.meta.has_more.after
  end

  test "send_message/3 attaches audio payload with caption metadata", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, upload, _instructions} =
      Media.create_upload(conversation.id, profile_a.id, %{
        "kind" => "audio",
        "content_type" => "audio/mpeg",
        "byte_size" => 1024
      })

    assert {:ok, message} =
             Chat.send_message(conversation.id, profile_a.id, %{
               "kind" => "audio",
               "media" => %{
                 "upload_id" => upload.id,
                 "durationMs" => 1500,
                 "caption" => "  Hør på dette  ",
                 "waveform" => [0, 50, 200],
                 "thumbnail" => %{
                   "url" => "https://cdn/thumb.jpg",
                   "width" => 120,
                   "height" => 80,
                   "bucket" => upload.bucket,
                   "objectKey" => upload.object_key <> "/preview"
                 }
               }
             })

    assert message.kind == :audio
    assert message.body == "Hør på dette"
    assert message.payload["media"]["objectKey"] == upload.object_key
    assert message.payload["media"]["durationMs"] == 1500
    assert message.payload["media"]["contentType"] == "audio/mpeg"
    assert message.payload["media"]["waveform"] == [0, 50, 100]
    assert %{"url" => "https://cdn/thumb.jpg", "width" => 120, "height" => 80} =
             message.payload["media"]["thumbnail"]
    assert %Upload{status: :consumed} = Repo.get!(Upload, upload.id)
  end

  test "send_message/3 validates media payload for images", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, upload, _} =
      Media.create_upload(conversation.id, profile_a.id, %{
        "kind" => "image",
        "content_type" => "image/png",
        "byte_size" => 12_000
      })

    assert {:error, changeset} =
             Chat.send_message(conversation.id, profile_a.id, %{
               "kind" => "image",
               "media" => %{"upload_id" => upload.id}
             })

    assert %{payload: ["missing media keys: width, height"]} = errors_on(changeset)

    assert {:ok, message} =
             Chat.send_message(conversation.id, profile_a.id, %{
               "kind" => "image",
               "media" => %{
                 "upload_id" => upload.id,
                 "caption" => "Skisse",
                 "width" => 800,
                 "height" => 600,
                 "thumbnail" => %{"url" => "https://cdn/thumb.jpg", "width" => 200, "height" => 150}
               }
             })

    assert message.kind == :image
    assert message.body == "Skisse"
    assert message.payload["media"]["width"] == 800
    assert message.payload["media"]["thumbnail"]["width"] == 200
  end

  test "send_message/3 validates audio waveform samples", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, upload, _} =
      Media.create_upload(conversation.id, profile_a.id, %{
        "kind" => "audio",
        "content_type" => "audio/mpeg",
        "byte_size" => 2048
      })

    assert {:error, changeset} =
             Chat.send_message(conversation.id, profile_a.id, %{
               "kind" => "audio",
               "media" => %{
                 "upload_id" => upload.id,
                 "waveform" => [0, 50, 2000]
               }
             })

    assert %{payload: ["waveform must be <=512 samples between 0 and 100"]} = errors_on(changeset)
  end

  test "send_message/3 validates thumbnail structure", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, upload, _} =
      Media.create_upload(conversation.id, profile_a.id, %{
        "kind" => "image",
        "content_type" => "image/jpeg",
        "byte_size" => 4096
      })

    assert {:error, changeset} =
             Chat.send_message(conversation.id, profile_a.id, %{
               "kind" => "image",
               "media" => %{
                 "upload_id" => upload.id,
                 "width" => 800,
                 "height" => 600,
                 "thumbnail" => %{"url" => "https://cdn/thumb.jpg", "width" => 0}
               }
             })

    assert %{payload: ["thumbnail dimensions must be positive numbers"]} = errors_on(changeset)
  end

  describe "message interactions" do
    setup %{profile_a: profile_a, profile_b: profile_b} do
      {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)
      {:ok, message} = Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

      {:ok,
       %{
         conversation: conversation,
         message: message,
         author: profile_a,
         other: profile_b
       }}
    end

    test "react_to_message/5 persists reaction and broadcasts", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      assert {:ok, reaction} =
               Chat.react_to_message(conversation.id, author.id, message.id, "👍")

      assert reaction.emoji == "👍"
      assert reaction.profile_id == author.id

      assert_receive {:reaction_added, payload}
      assert payload[:emoji] == "👍"

      aggregate = Enum.find(payload[:aggregates], &(&1[:emoji] == "👍"))
      assert aggregate[:count] == 1
      assert author.id in aggregate[:profile_ids]
    end

    test "remove_reaction/4 removes reaction and broadcasts", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      {:ok, _} = Chat.react_to_message(conversation.id, author.id, message.id, "❤️")

      assert {:ok, :removed} =
               Chat.remove_reaction(conversation.id, author.id, message.id, "❤️")

      assert_receive {:reaction_removed, payload}
      assert payload[:emoji] == "❤️"
      refute Enum.any?(payload[:aggregates], &(&1[:emoji] == "❤️" && &1[:count] > 0))
    end

    test "pin_message/4 stores pin and broadcasts", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      assert {:ok, pinned} =
               Chat.pin_message(conversation.id, author.id, message.id, %{"metadata" => %{"section" => "important"}})

      assert pinned.pinned_by_id == author.id
      assert pinned.metadata == %{"section" => "important"}

      assert_receive {:message_pinned, payload}
      assert payload[:message_id] == message.id
      assert payload[:pinned_by_id] == author.id
    end

    test "unpin_message/3 broadcasts removal", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)
      {:ok, _} = Chat.pin_message(conversation.id, author.id, message.id)

      assert {:ok, :unpinned} = Chat.unpin_message(conversation.id, author.id, message.id)

      assert_receive {:message_unpinned, payload}
      assert payload[:message_id] == message.id
    end

    test "mark_message_read/3 updates participant and broadcasts", %{
      conversation: conversation,
      message: message,
      other: other
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      assert {:ok, participant} =
               Chat.mark_message_read(conversation.id, other.id, message.id)

      assert participant.last_read_at

      assert_receive {:message_read, payload}
      assert payload[:profile_id] == other.id
      assert payload[:message_id] == message.id
    end

    test "update_message/4 updates body and broadcasts", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      assert {:ok, updated} =
               Chat.update_message(conversation.id, author.id, message.id, %{"body" => "Oppdatert"})

      assert updated.body == "Oppdatert"
      assert updated.edited_at

      assert_receive {:message_updated, broadcasted}
      assert broadcasted.body == "Oppdatert"
    end

    test "delete_message/4 marks message deleted and broadcasts", %{
      conversation: conversation,
      message: message,
      author: author
    } do
      :ok = Chat.subscribe_to_conversation(conversation.id)

      assert {:ok, deleted} =
               Chat.delete_message(conversation.id, author.id, message.id)

      assert deleted.deleted_at

      assert_receive {:message_deleted, payload}
      assert payload[:message_id] == message.id
      assert payload[:deleted_at]
    end
  end

  test "list_conversations/2 includes unread counts and last message", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

    page = Chat.list_conversations(profile_a.id)

    assert [conversation_summary] = page.entries
    assert conversation_summary.id == conversation.id
    assert conversation_summary.unread_count == 1
    assert conversation_summary.last_message.body == "Hei"
    assert page.meta.has_more == %{before: false, after: false}
  end

  test "broadcast_backlog/2 emits message backlog", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)
    {:ok, message} = Chat.send_message(conversation.id, profile_a.id, %{"body" => "Hei"})

    :ok = Chat.subscribe_to_conversation(conversation.id)

    page = Chat.list_messages(conversation.id)

    assert :ok = Chat.broadcast_backlog(conversation.id, page)
    assert_receive {:message_backlog, %{entries: [^message]} = payload}
    assert payload.meta.start_cursor == message.id
  end

  test "watch_conversation/2 tracks watchers", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, watch_payload} = Chat.watch_conversation(conversation.id, profile_a.id)
    assert watch_payload.count == 1
    assert Enum.any?(watch_payload.watchers, &(&1.id == profile_a.id))

    {:ok, watch_payload} = Chat.watch_conversation(conversation.id, profile_b.id)
    assert watch_payload.count == 2

    {:ok, unwatch_payload} = Chat.unwatch_conversation(conversation.id, profile_a.id)
    assert unwatch_payload.count == 1
    refute Enum.any?(unwatch_payload.watchers, &(&1.id == profile_a.id))
  end

  test "watchers expire after ttl", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    previous = Application.get_env(:msgr, :conversation_watcher_ttl_ms)
    Application.put_env(:msgr, :conversation_watcher_ttl_ms, 10)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:msgr, :conversation_watcher_ttl_ms)
      else
        Application.put_env(:msgr, :conversation_watcher_ttl_ms, previous)
      end
    end)

    {:ok, payload} = Chat.watch_conversation(conversation.id, profile_a.id)
    assert payload.count == 1

    Process.sleep(30)

    payload = Chat.list_watchers(conversation.id)
    assert payload.count == 0
    assert payload.watchers == []
  end
end
