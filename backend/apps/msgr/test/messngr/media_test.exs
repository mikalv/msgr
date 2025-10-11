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

  test "create_upload returns signed instructions and can be consumed with metadata", %{profile: profile, conversation: conversation} do
    {:ok, upload, instructions} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "image",
        "content_type" => "image/png",
        "byte_size" => 1_024_000,
        "filename" => "photo.png"
      })

    assert upload.kind == :image
    assert upload.status == :pending
    assert instructions["method"] == "PUT"
    assert instructions["bucket"] == upload.bucket
    assert instructions["objectKey"] == upload.object_key
    assert instructions["url"] =~ "X-Amz-Signature"
    assert instructions["retentionExpiresAt"]
    assert %{"objectKey" => thumb_key} = instructions["thumbnailUpload"]
    assert String.ends_with?(thumb_key, "-thumbnail.png")

    sha = String.duplicate("a", 64)

    {:ok, payload} =
      Media.consume_upload(upload.id, conversation.id, profile.id, %{
        "media" => %{
          "width" => 1920,
          "height" => 1080,
          "caption" => "  Sommerferie  ",
          "thumbnail" => %{"url" => "https://cdn/thumb.png", "width" => 320, "height" => 180},
          "sha256" => sha
        }
      })

    media_payload = payload["media"]
    assert media_payload["width"] == 1920
    assert media_payload["height"] == 1080
    assert media_payload["caption"] == "Sommerferie"
    assert media_payload["sha256"] == sha
    assert %{"url" => "https://cdn/thumb.png"} = media_payload["thumbnail"]
    assert payload["body"] == "Sommerferie"

    assert %Upload{status: :consumed, width: 1920, height: 1080, sha256: ^sha} = Repo.get!(Upload, upload.id)
  end

  test "consume_upload rejects invalid checksum", %{profile: profile, conversation: conversation} do
    {:ok, upload, _} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "audio",
        "content_type" => "audio/mpeg",
        "byte_size" => 2048
      })

    assert {:error, changeset} =
             Media.consume_upload(upload.id, conversation.id, profile.id, %{
               "media" => %{"sha256" => "not-a-digest"}
             })

    assert %{sha256: ["must be a valid SHA-256 hex digest"]} = errors_on(changeset)
  end
end
