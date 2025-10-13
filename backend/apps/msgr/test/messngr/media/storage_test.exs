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

  test "delete_object performs a signed DELETE request" do
    parent = self()

    client = fn %Finch.Request{method: "DELETE", url: url} = request ->
      send(parent, {:delete_request, request})
      assert url =~ "signature="
      {:ok, %Finch.Response{status: 204, body: "", headers: []}}
    end

    Application.put_env(:msgr, Storage, Keyword.put(Application.get_env(:msgr, Storage, []), :http_client, client))

    assert :ok = Storage.delete_object("media", "object-key")
    assert_received {:delete_request, %Finch.Request{method: "DELETE"}}
  end

  test "delete_object treats 404 as success" do
    client = fn _request ->
      {:ok, %Finch.Response{status: 404, body: "", headers: []}}
    end

    Application.put_env(:msgr, Storage, Keyword.put(Application.get_env(:msgr, Storage, []), :http_client, client))

    assert :ok = Storage.delete_object("media", "missing")
  end

  test "delete_object returns error for non-success responses" do
    client = fn _request ->
      {:ok, %Finch.Response{status: 500, body: "", headers: []}}
    end

    Application.put_env(:msgr, Storage, Keyword.put(Application.get_env(:msgr, Storage, []), :http_client, client))

    assert {:error, {:http_error, 500}} = Storage.delete_object("media", "object-key")
  end
end
