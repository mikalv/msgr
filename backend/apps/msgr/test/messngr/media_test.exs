defmodule Messngr.MediaTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat, Media, Repo}
  alias Messngr.Media.Upload

  setup do
    {:ok, account_a} = Accounts.create_account(%{"display_name" => "Kari"})
    profile = hd(account_a.profiles)

    {:ok, account_b} = Accounts.create_account(%{"display_name" => "Ola"})
    peer = hd(account_b.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, peer.id)

    {:ok,
     profile: profile,
     conversation: conversation}
  end

  test "create_upload returns instructions and can be consumed", %{profile: profile, conversation: conversation} do
    {:ok, upload, instructions} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "video",
        "content_type" => "video/mp4",
        "byte_size" => 2_000_000,
        "filename" => "clip.mp4"
      })

    assert upload.kind == :video
    assert upload.status == :pending
    assert instructions["method"] == "PUT"
    assert instructions["bucket"] == upload.bucket
    assert instructions["objectKey"] == upload.object_key

    {:ok, payload} =
      Media.consume_upload(upload.id, conversation.id, profile.id, %{"duration" => 12.5})

    assert payload["media"]["duration"] == 12.5
    assert payload["media"]["url"] =~ upload.object_key
    assert %Upload{status: :consumed} = Repo.get!(Upload, upload.id)
  end
end
