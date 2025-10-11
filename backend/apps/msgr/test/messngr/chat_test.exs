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
  end

  test "list_messages/2 respects limit", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    for body <- ["1", "2", "3"] do
      {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => body})
    end

    page = Chat.list_messages(conversation.id, limit: 2)
    assert Enum.map(page.entries, & &1.body) == ["2", "3"]
    assert page.meta.has_more
    assert page.meta.before_id
    assert page.meta.after_id
  end

  test "list_messages/2 supports after_id cursor", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    Enum.each(1..3, fn index ->
      {:ok, _} = Chat.send_message(conversation.id, profile_a.id, %{"body" => Integer.to_string(index)})
    end)

    first_page = Chat.list_messages(conversation.id, limit: 2)
    after_cursor = first_page.meta.after_id

    page = Chat.list_messages(conversation.id, limit: 2, after_id: after_cursor)

    assert Enum.map(page.entries, & &1.body) == ["3"]
    refute page.meta.has_more
    assert page.meta.before_id
  end

  test "list_conversations/2 returns unread counts and last message", %{
    profile_a: profile_a,
    profile_b: profile_b
  } do
    {:ok, conversation} = Chat.ensure_direct_conversation(profile_a.id, profile_b.id)

    {:ok, _} = Chat.send_message(conversation.id, profile_b.id, %{"body" => "Hei"})
    {:ok, _} = Chat.send_message(conversation.id, profile_b.id, %{"body" => "Hvordan går det?"})

    page = Chat.list_conversations(profile_a.id, limit: 10)

    assert length(page.entries) == 1

    [%{conversation: entry_conversation, unread_count: unread, last_message: last}] = page.entries

    assert entry_conversation.id == conversation.id
    assert unread == 2
    assert last.body == "Hvordan går det?"
    assert page.meta.after_id == conversation.id
    assert page.meta.before_id == conversation.id
  end

  test "send_message/3 attaches audio payload", %{profile_a: profile_a, profile_b: profile_b} do
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
               "body" => "Hør på dette",
               "media" => %{
                 "upload_id" => upload.id,
                 "durationMs" => 1500
               }
             })

    assert message.kind == :audio
    assert message.payload["media"]["objectKey"] == upload.object_key
    assert message.payload["media"]["durationMs"] == 1500
    assert message.payload["media"]["contentType"] == "audio/mpeg"
    assert %Upload{status: :consumed} = Repo.get!(Upload, upload.id)
  end
end
