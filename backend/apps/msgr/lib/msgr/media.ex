defmodule Messngr.Media do
  @moduledoc """
  Handles lifecycle of media uploads (audio/video) backed by object storage.
  Generates signed upload instructions and attaches metadata to chat messages.
  """

  alias Messngr.Media.{Storage, Upload}
  alias Messngr.Repo

  @type upload_instructions :: map()

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
          with {:ok, normalized_metadata, attrs} <- normalize_metadata(metadata),
               {:ok, updated} <- Upload.consume(upload, normalized_metadata, attrs) |> Repo.update() do
            Upload.payload(updated)
            |> put_retention()
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
    upload_signed =
      Storage.presign_upload(upload.bucket, upload.object_key, content_type: upload.content_type)

    download_signed =
      Storage.presign_download(upload.bucket, upload.object_key, content_type: upload.content_type)

    %{
      "id" => upload.id,
      "upload" => %{
        "method" => upload_signed.method,
        "url" => upload_signed.url,
        "headers" => upload_signed.headers,
        "expiresAt" => upload_signed.expires_at
      },
      "download" => %{
        "method" => download_signed.method,
        "url" => download_signed.url,
        "expiresAt" => download_signed.expires_at
      },
      "bucket" => upload.bucket,
      "objectKey" => upload.object_key,
      "publicUrl" => Storage.public_url(upload.bucket, upload.object_key),
      "retentionUntil" => retention_until(),
      "thumbnailUpload" => build_thumbnail_instructions(upload)
    }
  end

  defp build_thumbnail_instructions(%Upload{kind: kind} = upload) when kind in [:image, :video] do
    object_key = Upload.thumbnail_object_key(upload.object_key)
    upload_signed =
      Storage.presign_upload(upload.bucket, object_key, content_type: "image/jpeg")

    %{
      "method" => upload_signed.method,
      "url" => upload_signed.url,
      "headers" => upload_signed.headers,
      "bucket" => upload.bucket,
      "objectKey" => object_key,
      "publicUrl" => Storage.public_url(upload.bucket, object_key),
      "expiresAt" => upload_signed.expires_at
    }
  end

  defp build_thumbnail_instructions(_upload), do: nil

  defp config do
    Application.get_env(:msgr, __MODULE__, [])
  end

  defp put_retention(payload) do
    Map.update(payload, "media", %{}, fn media ->
      Map.put(media, "retention", %{"expiresAt" => retention_until()})
    end)
  end

  defp retention_until do
    ttl = Application.get_env(:msgr, __MODULE__, []) |> Keyword.get(:retention_ttl_seconds, 604_800)
    DateTime.add(DateTime.utc_now(), ttl, :second)
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    normalized = string_keys(metadata)

    {media_from_top_level, remaining} = extract_media_from_top_level(normalized)

    media =
      normalized
      |> Map.get("media")
      |> normalize_media()
      |> Map.merge(media_from_top_level)
      |> maybe_downcase_checksum()

    attrs = %{}
    attrs = maybe_put_attr(attrs, :width, Map.get(media, "width"))
    attrs = maybe_put_attr(attrs, :height, Map.get(media, "height"))
    attrs = maybe_put_attr(attrs, :checksum, Map.get(media, "checksum"))

    with :ok <- validate_checksum(Map.get(media, "checksum")) do
      normalized_media = maybe_put(remaining, "media", media)
      {:ok, normalized_media, attrs}
    end
  end

  defp normalize_metadata(_), do: {:ok, %{}, %{} }

  defp normalize_media(nil), do: %{}

  defp normalize_media(%{} = media) do
    media
    |> string_keys()
    |> normalize_thumbnail()
    |> normalize_waveform()
  end

  defp normalize_thumbnail(media) do
    case Map.get(media, "thumbnail") do
      %{} = thumbnail -> Map.put(media, "thumbnail", string_keys(thumbnail))
      _ -> media
    end
  end

  defp normalize_waveform(media) do
    case Map.get(media, "waveform") do
      waveform when is_list(waveform) ->
        normalized =
          waveform
          |> Enum.map(&normalize_waveform_point/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.take(512)

        Map.put(media, "waveform", normalized)

      _ ->
        media
    end
  end

  defp normalize_waveform_point(value) when is_integer(value), do: clamp_waveform(value / 1.0)
  defp normalize_waveform_point(value) when is_float(value), do: clamp_waveform(value)
  defp normalize_waveform_point(_), do: nil

  defp clamp_waveform(value) do
    value
    |> max(0.0)
    |> min(1.0)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_attr(attrs, _key, nil), do: attrs
  defp maybe_put_attr(attrs, key, value), do: Map.put(attrs, key, value)

  defp maybe_downcase_checksum(media) do
    case Map.get(media, "checksum") do
      checksum when is_binary(checksum) -> Map.put(media, "checksum", String.downcase(checksum))
      _ -> media
    end
  end

  defp validate_checksum(nil), do: :ok

  defp validate_checksum(value) when is_binary(value) do
    if Regex.match?(~r/\A[A-Fa-f0-9]{32,128}\z/, value) do
      :ok
    else
      {:error, :checksum_invalid}
    end
  end

  defp validate_checksum(_), do: {:error, :checksum_invalid}

  defp extract_media_from_top_level(map) do
    Enum.reduce(map, {%{}, %{}}, fn
      {"media", value}, {media_acc, remaining_acc} ->
        {media_acc, Map.put(remaining_acc, "media", value)}

      {key, value}, {media_acc, remaining_acc}
      when key in ["caption", "checksum", "duration", "durationMs", "waveform", "width", "height", "thumbnail", "metadata", "waveformSampleRate"] ->
        {Map.put(media_acc, key, value), remaining_acc}

      {key, value}, {media_acc, remaining_acc} ->
        {media_acc, Map.put(remaining_acc, key, value)}
    end)
  end

  defp string_keys(map) do
    for {key, value} <- map, into: %{} do
      normalized_key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> to_string(other)
        end

      normalized_value =
        case value do
          %{} = nested -> string_keys(nested)
          list when is_list(list) -> Enum.map(list, &convert_value/1)
          other -> other
        end

      {normalized_key, normalized_value}
    end
  end

  defp convert_value(%{} = map), do: string_keys(map)
  defp convert_value(value), do: value
end
