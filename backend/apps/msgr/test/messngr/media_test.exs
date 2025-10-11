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
    assert instructions["bucket"] == upload.bucket
    assert instructions["objectKey"] == upload.object_key
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
          "duration" => 12.5,
          "checksum" => String.duplicate("a", 64),
          "width" => 1920,
          "height" => 1080,
          "thumbnail" => %{
            "bucket" => upload.bucket,
            "objectKey" => upload.object_key <> "/thumbnail"
          }
        }
      })

    media_payload = payload["media"]
    assert media_payload["duration"] == 12.5
    assert media_payload["checksum"] == String.duplicate("a", 64)
    assert media_payload["width"] == 1920
    assert media_payload["height"] == 1080
    assert media_payload["url"] =~ upload.object_key
    assert %{"expiresAt" => _} = media_payload["retention"]
    assert %{"url" => thumb_url} = media_payload["thumbnail"]
    assert thumb_url =~ "thumbnail"
    assert %Upload{status: :consumed} = Repo.get!(Upload, upload.id)
  end

  test "consume_upload rejects invalid checksum", %{profile: profile, conversation: conversation} do
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
