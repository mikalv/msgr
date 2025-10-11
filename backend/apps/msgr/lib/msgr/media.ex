defmodule Messngr.Media do
  @moduledoc """
  Handles lifecycle of media uploads (audio/video) backed by object storage.
  Generates signed upload instructions and attaches metadata to chat messages.
  """

  alias Messngr.Media.{Storage, Upload}
  alias Messngr.Repo

  @type upload_instructions :: %{
          required("id") => String.t(),
          required("method") => String.t(),
          required("url") => String.t(),
          required("headers") => map(),
          required("bucket") => String.t(),
          required("objectKey") => String.t(),
          required("publicUrl") => String.t(),
          required("expiresAt") => DateTime.t()
        }

  @doc """
  Creates a new upload request and returns the storage instructions needed to
  PUT the binary directly to object storage (e.g. MinIO).
  """
  @spec create_upload(binary(), binary(), map()) ::
          {:ok, Upload.t(), upload_instructions()} | {:error, Ecto.Changeset.t()}
  def create_upload(conversation_id, profile_id, attrs) do
    params =
      attrs
      |> Map.put_new("conversation_id", conversation_id)
      |> Map.put_new("profile_id", profile_id)
      |> normalise_kind()
      |> ensure_bucket()
      |> ensure_object_key(conversation_id)
      |> ensure_expires_at()
      |> ensure_retention()

    %Upload{}
    |> Upload.creation_changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, upload} ->
        {:ok, upload, build_instructions(upload)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Marks an upload as consumed and returns the media payload that should be
  embedded into a chat message.
  """
  @spec consume_upload(binary(), binary(), binary(), map()) ::
          {:ok, map()} | {:error, term()}
  def consume_upload(upload_id, conversation_id, profile_id, metadata \\ %{}) do
    Repo.transaction(fn ->
      upload = Repo.get_for_update(Upload, upload_id)

      cond do
        is_nil(upload) -> Repo.rollback(:not_found)
        upload.conversation_id != conversation_id -> Repo.rollback(:invalid_conversation)
        upload.profile_id != profile_id -> Repo.rollback(:invalid_profile)
        upload.status != :pending -> Repo.rollback(:already_consumed)
        Upload.expired?(upload) -> Repo.rollback(:expired)
        true ->
          with {:ok, updated} <- Upload.consume(upload, metadata) |> Repo.update() do
            Upload.payload(updated)
          else
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
  end

  defp normalise_kind(attrs) do
    case Map.fetch(attrs, "kind") do
      {:ok, kind} when is_binary(kind) -> Map.put(attrs, "kind", String.downcase(kind))
      _ -> attrs
    end
  end

  defp ensure_bucket(attrs) do
    Map.put_new(attrs, "bucket", Storage.bucket())
  end

  defp ensure_object_key(attrs, conversation_id) do
    case Map.get(attrs, "object_key") || Map.get(attrs, "objectKey") do
      nil ->
        filename = Map.get(attrs, "filename")
        kind = Map.get(attrs, "kind")
        key = Storage.object_key(conversation_id, kind, filename)
        Map.put(attrs, "object_key", key)

      key ->
        Map.put(attrs, "object_key", key)
    end
  end

  defp ensure_expires_at(attrs) do
    Map.put_new_lazy(attrs, "expires_at", fn ->
      ttl = config() |> Keyword.get(:upload_ttl_seconds, 900)
      DateTime.add(DateTime.utc_now(), ttl, :second)
    end)
  end

  defp ensure_retention(attrs) do
    Map.put_new_lazy(attrs, "retention_expires_at", fn ->
      retention_days =
        attrs
        |> Map.get("retention_days")
        |> Kernel.||(config() |> Keyword.get(:retention_days, 30))

      DateTime.add(DateTime.utc_now(), retention_days * 86_400, :second)
    end)
  end

  defp build_instructions(%Upload{} = upload) do
    signed_url = Storage.presign_upload(upload.bucket, upload.object_key, upload.expires_at)

    %{
      "id" => upload.id,
      "method" => "PUT",
      "url" => signed_url,
      "headers" => %{"content-type" => upload.content_type},
      "bucket" => upload.bucket,
      "objectKey" => upload.object_key,
      "publicUrl" => Storage.public_url(upload.bucket, upload.object_key),
      "expiresAt" => upload.expires_at,
      "retentionExpiresAt" => upload.retention_expires_at,
      "thumbnailUpload" => build_thumbnail_instructions(upload)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp build_thumbnail_instructions(%Upload{kind: kind} = upload) when kind in [:image, :video] do
    object_key = Upload.thumbnail_object_key(upload.object_key)
    signed_url = Storage.presign_upload(upload.bucket, object_key, upload.expires_at)

    %{
      "method" => "PUT",
      "url" => signed_url,
      "headers" => %{"content-type" => "image/jpeg"},
      "bucket" => upload.bucket,
      "objectKey" => object_key,
      "publicUrl" => Storage.public_url(upload.bucket, object_key),
      "expiresAt" => upload.expires_at
    }
  end

  defp build_thumbnail_instructions(_upload), do: nil

  defp config do
    Application.get_env(:msgr, __MODULE__, [])
  end
end
