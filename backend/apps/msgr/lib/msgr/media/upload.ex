defmodule Messngr.Media.Upload do
  @moduledoc """
  Schema for pending media uploads that are later attached to chat messages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc """
  Metadata stored on the media upload record.
  """
  @type metadata :: map()

  schema "media_uploads" do
    field :kind, Ecto.Enum, values: [:audio, :video, :image, :file, :voice, :thumbnail]
    field :status, Ecto.Enum, values: [:pending, :consumed], default: :pending
    field :bucket, :string
    field :object_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :metadata, :map, default: %{}
    field :expires_at, :utc_datetime
    field :width, :integer
    field :height, :integer
    field :checksum, :string

    belongs_to :conversation, Messngr.Chat.Conversation
    belongs_to :profile, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def creation_changeset(upload, attrs) do
    upload
    |> cast(attrs, [
      :kind,
      :status,
      :bucket,
      :object_key,
      :content_type,
      :byte_size,
      :metadata,
      :expires_at,
      :conversation_id,
      :profile_id,
      :width,
      :height,
      :checksum
    ])
    |> validate_required([
      :kind,
      :bucket,
      :object_key,
      :content_type,
      :byte_size,
      :expires_at,
      :conversation_id,
      :profile_id
    ])
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_format(:content_type, ~r{/})
    |> validate_number(:width, greater_than: 0, allow_nil: true)
    |> validate_number(:height, greater_than: 0, allow_nil: true)
    |> validate_checksum()
    |> unique_constraint(:object_key)
  end

  @doc """
  Builds a changeset that marks the upload as consumed and persists metadata.
  """
  @spec consume(t(), map(), keyword()) :: Ecto.Changeset.t()
  def consume(%__MODULE__{} = upload, metadata, attrs \\ []) do
    update_attrs =
      attrs
      |> Enum.into(%{})
      |> Map.take([:width, :height, :checksum])

    upload
    |> change(Map.merge(%{status: :consumed}, update_attrs))
    |> change(metadata: merge_metadata(upload.metadata, metadata))
  end

  @doc """
  Whether the upload has expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: false
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Constructs the payload that should be embedded in a message once the upload
  has been consumed.
  """
  @spec payload(t()) :: map()
  def payload(%__MODULE__{} = upload) do
    download =
      Messngr.Media.Storage.presign_download(upload.bucket, upload.object_key,
        content_type: upload.content_type
      )

    base_media =
      %{
        "bucket" => upload.bucket,
        "objectKey" => upload.object_key,
        "contentType" => upload.content_type,
        "byteSize" => upload.byte_size,
        "url" => download.url,
        "urlExpiresAt" => download.expires_at,
        "checksum" => upload.checksum,
        "width" => upload.width,
        "height" => upload.height
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    %{"media" => base_media}
    |> merge_metadata(upload.metadata)
    |> maybe_presign_thumbnail()
  end

  defp merge_metadata(base, metadata) when is_map(metadata) do
    normalized = for {key, value} <- metadata, into: %{}, do: {to_string(key), value}
    media_overrides =
      case Map.get(normalized, "media") do
        %{} = nested -> Map.merge(Map.delete(normalized, "media"), nested)
        _ -> normalized
      end

    media = Map.get(base || %{}, "media", %{})
    updated_media = Map.merge(media, media_overrides, fn _key, _old, new -> new end)

    Map.put(base || %{"media" => %{}}, "media", updated_media)
  end

  defp merge_metadata(base, _), do: base || %{}

  defp maybe_presign_thumbnail(%{"media" => %{"thumbnail" => %{} = thumbnail}} = payload) do
    bucket = Map.get(thumbnail, "bucket") || Map.get(thumbnail, "bucketName")
    object_key = Map.get(thumbnail, "object_key") || Map.get(thumbnail, "objectKey")

    cond do
      is_binary(bucket) and is_binary(object_key) ->
        download = Messngr.Media.Storage.presign_download(bucket, object_key)

        updated =
          thumbnail
          |> Map.put_new("bucket", bucket)
          |> Map.put("objectKey", object_key)
          |> Map.put("url", download.url)
          |> Map.put("urlExpiresAt", download.expires_at)

        put_in(payload, ["media", "thumbnail"], updated)

      true ->
        payload
    end
  end

  defp maybe_presign_thumbnail(payload), do: payload

  defp validate_checksum(changeset) do
    checksum = get_field(changeset, :checksum)

    cond do
      is_nil(checksum) -> changeset
      Regex.match?(~r/\A[A-Fa-f0-9]{32,128}\z/, checksum) -> changeset
      true -> add_error(changeset, :checksum, "must be a hexadecimal digest")
    end
  end
end
