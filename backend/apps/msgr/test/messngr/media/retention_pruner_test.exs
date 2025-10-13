defmodule Messngr.Media.RetentionPrunerTest do
  use Messngr.DataCase

  alias Ecto.Changeset
  alias Messngr.{Accounts, Chat, Media, Repo}
  alias Messngr.Media.{Storage, Upload}

  setup do
    {:ok, account_a} = Accounts.create_account(%{"display_name" => "Kari"})
    profile = hd(account_a.profiles)

    {:ok, account_b} = Accounts.create_account(%{"display_name" => "Ola"})
    peer = hd(account_b.profiles)

    {:ok, conversation} = Chat.ensure_direct_conversation(profile.id, peer.id)

    original_storage_config = Application.get_env(:msgr, Storage, [])

    on_exit(fn ->
      Application.put_env(:msgr, Storage, original_storage_config)
    end)

    {:ok,
     profile: profile,
     conversation: conversation,
     storage_config: original_storage_config}
  end

  test "prune_expired_uploads removes expired uploads and storage objects", %{
    profile: profile,
    conversation: conversation,
    storage_config: storage_config
  } do
    now = DateTime.utc_now()
    parent = self()

    delete_client = fn %Finch.Request{} = request ->
      send(parent, {:deleted, request.url})
      {:ok, %Finch.Response{status: 204, body: "", headers: []}}
    end

    Application.put_env(:msgr, Storage, Keyword.put(storage_config, :http_client, delete_client))

    {:ok, expired_upload, _} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "image",
        "content_type" => "image/png",
        "byte_size" => 1024,
        "filename" => "photo.png"
      })

    thumbnail_key = Upload.thumbnail_object_key(expired_upload.object_key)

    expired_upload =
      expired_upload
      |> Changeset.change(%{
        retention_expires_at: DateTime.add(now, -60, :second),
        status: :consumed,
        metadata: %{
          "media" => %{
            "thumbnail" => %{
              "bucket" => expired_upload.bucket,
              "objectKey" => thumbnail_key
            }
          }
        }
      })
      |> Repo.update!()

    {:ok, fresh_upload, _} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "audio",
        "content_type" => "audio/mpeg",
        "byte_size" => 2048
      })

    result = Media.prune_expired_uploads(now: now, limit: 10)

    assert %{scanned: 1, deleted: 1, errors: []} = result
    refute Repo.get(Upload, expired_upload.id)
    assert Repo.get(Upload, fresh_upload.id)

    deleted_urls =
      for _ <- 1..2 do
        assert_receive {:deleted, url}
        url
      end

    assert Enum.any?(deleted_urls, &String.contains?(&1, expired_upload.object_key))
    assert Enum.any?(deleted_urls, &String.contains?(&1, thumbnail_key))
    refute_receive {:deleted, _}
  end

  test "prune_expired_uploads reports errors without deleting records", %{
    profile: profile,
    conversation: conversation,
    storage_config: storage_config
  } do
    Application.put_env(:msgr, Storage, Keyword.put(storage_config, :http_client, fn _ -> {:error, :timeout} end))

    {:ok, upload, _} =
      Media.create_upload(conversation.id, profile.id, %{
        "kind" => "file",
        "content_type" => "application/pdf",
        "byte_size" => 4096
      })

    upload =
      upload
      |> Changeset.change(retention_expires_at: DateTime.add(DateTime.utc_now(), -120, :second))
      |> Repo.update!()

    result = Media.prune_expired_uploads(limit: 5)

    assert %{scanned: 1, deleted: 0, errors: [%{id: ^upload.id, reason: :timeout}]} = result
    assert Repo.get!(Upload, upload.id)
  end
end
