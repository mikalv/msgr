defmodule Messngr.Media.Storage do
  @moduledoc """
  Configuration backed helper for generating object storage URLs and keys.
  """

  @spec bucket() :: String.t()
  def bucket do
    config() |> Keyword.get(:bucket, "msgr-media")
  end

  @spec endpoint() :: String.t()
  def endpoint do
    config() |> Keyword.get(:endpoint, "http://localhost:9000")
  end

  @spec public_endpoint() :: String.t()
  def public_endpoint do
    config() |> Keyword.get(:public_endpoint, endpoint())
  end

  @spec object_key(binary(), binary() | nil, binary() | nil) :: String.t()
  def object_key(conversation_id, kind, filename) do
    extension = filename && Path.extname(filename) || ""
    cleaned = extension |> to_string() |> String.trim()
    type = kind || "media"
    uuid = UUID.uuid4()

    ["conversations", conversation_id, type, uuid <> cleaned]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Path.join()
  end

  @spec upload_url(String.t(), String.t()) :: String.t()
  def upload_url(bucket, object_key) do
    URI.merge(endpoint(), "#{bucket}/#{object_key}") |> to_string()
  end

  @spec presign_upload(String.t(), String.t(), DateTime.t(), keyword()) :: String.t()
  def presign_upload(bucket, object_key, expires_at, opts \\ []) do
    ttl_seconds =
      opts
      |> Keyword.get(:ttl_seconds, max(DateTime.diff(expires_at, DateTime.utc_now(), :second), 60))

    secret = config() |> Keyword.get(:secret, "development-secret")
    payload = Enum.join([bucket, object_key, Integer.to_string(ttl_seconds)], ":")
    signature = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.url_encode64(padding: false)

    upload_url(bucket, object_key) <> "?X-Amz-Expires=#{ttl_seconds}&X-Amz-Signature=#{signature}"
  end

  @spec public_url(String.t(), String.t()) :: String.t()
  def public_url(bucket, object_key) do
    URI.merge(public_endpoint(), "#{bucket}/#{object_key}") |> to_string()
  end

  defp config do
    Application.get_env(:msgr, __MODULE__, [])
  end
end
