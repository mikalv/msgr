defmodule Messngr.Media.StorageTest do
  use ExUnit.Case, async: false

  alias Messngr.Media.Storage

  test "object_key builds a conversation-scoped path" do
    key = Storage.object_key("conv-1", "image", "photo.png")
    assert String.starts_with?(key, "conversations/conv-1/image/")
    assert String.ends_with?(key, ".png")
  end

  test "public_url joins endpoint, bucket and object key" do
    url = Storage.public_url("msgr-media", "conversations/1/file.bin")
    assert url =~ "msgr-media/conversations/1/file.bin"
  end

  test "presign_upload returns a PUT URL" do
    result = Storage.presign_upload("msgr-media", "object-key", content_type: "image/png")

    assert result.method == "PUT"
    assert is_binary(result.url)
    assert result.url =~ "object-key"
    assert %DateTime{} = result.expires_at
    assert result.headers["content-type"] == "image/png"
  end

  test "presign_download returns a GET URL" do
    result = Storage.presign_download("msgr-media", "object-key")

    assert result.method == "GET"
    assert is_binary(result.url)
    assert result.url =~ "object-key"
    assert %DateTime{} = result.expires_at
  end
end
