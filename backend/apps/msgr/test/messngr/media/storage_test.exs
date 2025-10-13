defmodule Messngr.Media.StorageTest do
  use ExUnit.Case, async: false

  alias Messngr.Media.Storage

  setup do
    original = Application.get_env(:msgr, Storage, [])

    Application.put_env(:msgr, Storage, Keyword.put(original, :signing_secret, "test-secret"))

    on_exit(fn ->
      Application.put_env(:msgr, Storage, original)
    end)

    :ok
  end

  test "presign_download embeds checksum into the query" do
    result = Storage.presign_download("bucket", "object-key", checksum: "abc123", content_type: "image/png")

    params =
      result.url
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()

    assert params["checksum"] == "abc123"
    assert params["signature"]
  end

  test "signatures change when checksum changes" do
    first = Storage.presign_download("bucket", "object-key", checksum: "one")
    second = Storage.presign_download("bucket", "object-key", checksum: "two")

    params_one = first.url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    params_two = second.url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    refute params_one["signature"] == params_two["signature"]
  end

  test "raises when signing secret is missing" do
    current = Application.get_env(:msgr, Storage, [])
    Application.put_env(:msgr, Storage, Keyword.delete(current, :signing_secret))

    assert_raise ArgumentError, ~r/signing secret is not configured/, fn ->
      Storage.presign_download("bucket", "object-key")
    end
  end
end
