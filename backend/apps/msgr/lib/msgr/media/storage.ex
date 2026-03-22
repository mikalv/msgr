defmodule Messngr.Media.Storage do
  @moduledoc """
  S3/MinIO storage with real presigned URLs via ExAws.

  Replaces the previous custom HMAC-signed URL scheme with proper
  AWS Signature V4 presigned URLs that MinIO understands natively.
  """

  require Logger

  @spec bucket() :: String.t()
  def bucket do
    config() |> Keyword.get(:bucket, "msgr-media")
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

  @spec presign_upload(String.t(), String.t(), keyword()) :: %{
          required(:method) => String.t(),
          required(:url) => String.t(),
          required(:expires_at) => DateTime.t(),
          required(:headers) => map()
        }
  def presign_upload(bucket, object_key, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    ttl = config() |> Keyword.get(:upload_expiry_seconds, 900)

    {:ok, url} =
      ExAws.S3.presigned_url(
        presign_config(),
        :put,
        bucket,
        object_key,
        expires_in: ttl,
        query_params: [{"Content-Type", content_type}]
      )

    headers = %{"content-type" => content_type}

    %{
      method: "PUT",
      url: url,
      expires_at: DateTime.add(DateTime.utc_now(), ttl, :second),
      headers: headers
    }
  end

  @spec presign_download(String.t(), String.t(), keyword()) :: %{
          required(:method) => String.t(),
          required(:url) => String.t(),
          required(:expires_at) => DateTime.t()
        }
  def presign_download(bucket, object_key, _opts \\ []) do
    ttl = config() |> Keyword.get(:download_expiry_seconds, 3600)

    {:ok, url} =
      ExAws.S3.presigned_url(
        presign_config(),
        :get,
        bucket,
        object_key,
        expires_in: ttl
      )

    %{
      method: "GET",
      url: url,
      expires_at: DateTime.add(DateTime.utc_now(), ttl, :second)
    }
  end

  @spec public_url(String.t(), String.t()) :: String.t()
  def public_url(bucket, object_key) do
    public_endpoint = config() |> Keyword.get(:public_endpoint, "http://localhost:9000")
    URI.merge(public_endpoint, "#{bucket}/#{object_key}") |> to_string()
  end

  @spec delete_object(String.t(), String.t()) :: :ok | {:error, term()}
  def delete_object(bucket, object_key) do
    case ExAws.S3.delete_object(bucket, object_key) |> ExAws.request(internal_overrides()) do
      {:ok, _} -> :ok
      {:error, {:http_error, 404, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ensure_bucket!(String.t()) :: :ok
  def ensure_bucket!(bucket_name) do
    overrides = internal_overrides()
    Logger.info("Checking media bucket '#{bucket_name}' via #{inspect(overrides)}")

    case ExAws.S3.head_bucket(bucket_name) |> ExAws.request(overrides) do
      {:ok, _} ->
        Logger.info("Media bucket '#{bucket_name}' exists")
        :ok

      {:error, _} ->
        Logger.info("Creating media bucket '#{bucket_name}'...")
        ExAws.S3.put_bucket(bucket_name, "us-east-1") |> ExAws.request!(overrides)
        Logger.info("Media bucket '#{bucket_name}' created")
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp config do
    Application.get_env(:msgr, __MODULE__, [])
  end

  # Config overrides for internal operations (bucket creation, delete, etc.)
  # Uses the internal endpoint (e.g. http://msgr_minio:9000) so we talk
  # directly to MinIO, not via the public TLS proxy.
  defp internal_overrides do
    internal = config() |> Keyword.get(:internal_endpoint, "http://localhost:9000")
    uri = URI.parse(internal)

    %{
      scheme: "#{uri.scheme}://",
      host: uri.host,
      port: uri.port || 9000,
      force_path_style: true
    }
  end

  # Config for presigned URLs — uses PUBLIC host so signatures match
  # what the client sends. This is the correct way to handle reverse proxies.
  defp presign_config do
    public = config() |> Keyword.get(:public_endpoint, "http://localhost:9000")
    uri = URI.parse(public)

    ExAws.Config.new(:s3, %{
      scheme: "#{uri.scheme}://",
      host: uri.host,
      port: uri.port || (if uri.scheme == "https", do: 443, else: 80),
      force_path_style: true
    })
  end

  defp encryption_headers do
    cfg = config()

    case cfg |> Keyword.get(:server_side_encryption) |> blank_to_nil() do
      nil ->
        %{}

      algorithm ->
        headers = %{"x-amz-server-side-encryption" => algorithm}

        case cfg |> Keyword.get(:sse_kms_key_id) |> blank_to_nil() do
          nil -> headers
          kms_key -> Map.put(headers, "x-amz-server-side-encryption-aws-kms-key-id", kms_key)
        end
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
