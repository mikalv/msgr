defmodule Messngr.MediaTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Chat, Media, Repo}
  alias Messngr.Media.{Storage, Upload}

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
    assert instructions["bucket"] == upload.bucket
    assert instructions["objectKey"] == upload.object_key
    assert instructions["url"] =~ "X-Amz-Signature"
    assert instructions["retentionExpiresAt"]
    assert %{"objectKey" => thumb_key} = instructions["thumbnailUpload"]
    assert String.ends_with?(thumb_key, "-thumbnail.png")

    sha = String.duplicate("a", 64)
    assert %{"method" => "PUT", "url" => upload_url, "headers" => headers} = instructions["upload"]
    assert headers["content-type"] == "video/mp4"
    assert headers["x-amz-server-side-encryption"] == "AES256"
    assert upload_url =~ "signature="
    assert %{"url" => download_url} = instructions["download"]
    assert download_url =~ upload.object_key
    assert %DateTime{} = instructions["retentionUntil"]

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

  test "consume_upload rejects invalid sha digest", %{profile: profile, conversation: conversation} do
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

  test "consume_upload returns checksum error for malformed checksum field", %{profile: profile, conversation: conversation} do
    {:ok, upload, _instructions} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "audio",
        "content_type" => "audio/mpeg",
        "byte_size" => 2_000
      })

    assert {:error, :checksum_invalid} =
             Media.consume_upload(upload.id, conversation.id, profile.id, %{
               "media" => %{"checksum" => "not_hex"}
             })
  end

  test "creation_changeset validates checksum format", %{profile: profile, conversation: conversation} do
    params = %{
      "kind" => "image",
      "bucket" => "media",
      "object_key" => "conversations/#{conversation.id}/image/test.png",
      "content_type" => "image/png",
      "byte_size" => 1024,
      "expires_at" => DateTime.utc_now(),
      "conversation_id" => conversation.id,
      "profile_id" => profile.id,
      "checksum" => "invalid"
    }

    changeset = Upload.creation_changeset(%Upload{}, params)
    refute changeset.valid?
    assert %{checksum: ["must be a hexadecimal digest"]} = errors_on(changeset)
  end

  test "presign_upload includes kms headers when configured" do
    original = Application.get_env(:msgr, Storage, [])

    updated =
      original
      |> Keyword.put(:server_side_encryption, "aws:kms")
      |> Keyword.put(:sse_kms_key_id, "test-key-id")

    Application.put_env(:msgr, Storage, updated)

    on_exit(fn -> Application.put_env(:msgr, Storage, original) end)

    signed = Storage.presign_upload("bucket", "object", content_type: "image/png")

    assert signed.headers["x-amz-server-side-encryption"] == "aws:kms"
    assert signed.headers["x-amz-server-side-encryption-aws-kms-key-id"] == "test-key-id"
  end
end
