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
    assert Enum.count(conversation.participants) == 2
  end

  test "create_group_conversation/3 creates group with owner", %{profile_a: profile_a, profile_b: profile_b} do
    {:ok, account_c} = Accounts.create_account(%{"display_name" => "Per"})
    profile_c = List.first(account_c.profiles)

    assert {:ok, conversation} =
             Chat.create_group_conversation(profile_a.id, [profile_b.id, profile_c.id], %{"topic" => "Plan"})

    assert conversation.kind == :group
    assert conversation.topic == "Plan"
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
    assert Enum.any?(conversation.participants, &(&1.role == :member && &1.profile.id == profile_b.id))
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
