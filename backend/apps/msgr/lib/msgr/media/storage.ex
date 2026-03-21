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
        ex_aws_config(),
        :put,
        bucket,
        object_key,
        expires_in: ttl,
        query_params: [{"Content-Type", content_type}]
      )

    url = maybe_replace_host(url)

    headers =
      encryption_headers()
      |> Map.put("content-type", content_type)

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
        ex_aws_config(),
        :get,
        bucket,
        object_key,
        expires_in: ttl
      )

    url = maybe_replace_host(url)

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
    case ExAws.S3.delete_object(bucket, object_key) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, {:http_error, 404, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ensure_bucket!(String.t()) :: :ok
  def ensure_bucket!(bucket_name) do
    case ExAws.S3.head_bucket(bucket_name) |> ExAws.request() do
      {:ok, _} ->
        Logger.info("Media bucket '#{bucket_name}' exists")
        :ok

      {:error, _} ->
        Logger.info("Creating media bucket '#{bucket_name}'...")
        ExAws.S3.put_bucket(bucket_name, "us-east-1") |> ExAws.request!()
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

  defp ex_aws_config do
    ExAws.Config.new(:s3)
  end

  @doc false
  # Replace the internal MinIO hostname (e.g. msgr_minio:9000 inside Docker)
  # with the public-facing endpoint so clients can actually reach the URL.
  defp maybe_replace_host(url) do
    internal = config() |> Keyword.get(:internal_endpoint)
    public = config() |> Keyword.get(:public_endpoint)

    cond do
      is_nil(internal) or is_nil(public) -> url
      internal == public -> url
      true -> String.replace(url, internal, public)
    end
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
