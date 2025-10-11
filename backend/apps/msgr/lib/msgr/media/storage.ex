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

  @spec presign_upload(String.t(), String.t(), keyword()) :: %{
          required(:method) => String.t(),
          required(:url) => String.t(),
          required(:expires_at) => DateTime.t(),
          required(:headers) => map()
        }
  def presign_upload(bucket, object_key, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    expires_at = expires_at(:upload)

    headers =
      encryption_headers()
      |> Map.put("content-type", content_type)

    url =
      presigned_url(:put, endpoint(), bucket, object_key, expires_at,
        content_type: content_type,
        headers: headers
      )

    %{
      method: "PUT",
      url: url,
      expires_at: expires_at,
      headers: headers
    }
  end

  @spec presign_download(String.t(), String.t(), keyword()) :: %{
          required(:method) => String.t(),
          required(:url) => String.t(),
          required(:expires_at) => DateTime.t()
        }
  def presign_download(bucket, object_key, opts \\ []) do
    content_type = Keyword.get(opts, :content_type)
    expires_at = expires_at(:download)

    url =
      presigned_url(:get, public_endpoint(), bucket, object_key, expires_at,
        content_type: content_type
      )

    %{
      method: "GET",
      url: url,
      expires_at: expires_at
    }
  end

  defp config do
    Application.get_env(:msgr, __MODULE__, [])
  end

  defp presigned_url(method, base, bucket, object_key, expires_at, opts) do
    uri = URI.merge(base, "#{bucket}/#{object_key}")
    expires = DateTime.to_unix(expires_at)
    content_type = Keyword.get(opts, :content_type)
    headers = Keyword.get(opts, :headers, %{})
    signature = sign(method, uri.path || "/", expires, content_type, headers)

    query_params =
      %{expires: expires, signature: signature}
      |> maybe_put_content_type(content_type)

    uri
    |> Map.put(:query, URI.encode_query(query_params))
    |> to_string()
  end

  defp sign(method, path, expires, content_type, headers) do
    secret = config() |> Keyword.get(:signing_secret, "dev-secret")
    canonical_headers = canonical_headers(headers)

    payload =
      [
        method |> to_string() |> String.upcase(),
        path,
        Integer.to_string(expires),
        content_type || "",
        canonical_headers
      ]
      |> Enum.join(":")

    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.url_encode64(padding: false)
  end

  defp canonical_headers(headers) when map_size(headers) == 0, do: ""

  defp canonical_headers(headers) do
    headers
    |> Enum.map(fn {key, value} ->
      normalized_key =
        key
        |> to_string()
        |> String.downcase()
        |> String.trim()

      "#{normalized_key}=#{value}"
    end)
    |> Enum.sort()
    |> Enum.join("&")
  end

  defp maybe_put_content_type(params, nil), do: params

  defp maybe_put_content_type(params, content_type) do
    Map.put(params, :content_type, content_type)
  end

  defp encryption_headers do
    config = config()

    case config |> Keyword.get(:server_side_encryption) |> blank_to_nil() do
      nil -> %{}
      algorithm ->
        headers = %{"x-amz-server-side-encryption" => algorithm}

        case config |> Keyword.get(:sse_kms_key_id) |> blank_to_nil() do
          nil -> headers
          kms_key -> Map.put(headers, "x-amz-server-side-encryption-aws-kms-key-id", kms_key)
        end
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp expires_at(kind) do
    seconds =
      case kind do
        :upload -> config() |> Keyword.get(:upload_expiry_seconds, 600)
        :download -> config() |> Keyword.get(:download_expiry_seconds, 1200)
      end

    DateTime.add(DateTime.utc_now(), seconds, :second)
  end
end
