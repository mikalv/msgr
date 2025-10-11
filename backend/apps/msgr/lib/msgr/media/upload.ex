defmodule Messngr.Media.Upload do
  @moduledoc """
  Schema for pending media uploads that are later attached to chat messages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "media_uploads" do
    field :kind, Ecto.Enum, values: [:audio, :video]
    field :status, Ecto.Enum, values: [:pending, :consumed], default: :pending
    field :bucket, :string
    field :object_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :metadata, :map, default: %{}
    field :expires_at, :utc_datetime

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
      :profile_id
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
    |> unique_constraint(:object_key)
  end

  @doc """
  Builds a changeset that marks the upload as consumed and persists metadata.
  """
  @spec consume(t(), map()) :: Ecto.Changeset.t()
  def consume(%__MODULE__{} = upload, metadata) do
    upload
    |> change(status: :consumed, metadata: merge_metadata(upload.metadata, metadata))
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
    %{
      "media" => %{
        "bucket" => upload.bucket,
        "objectKey" => upload.object_key,
        "contentType" => upload.content_type,
        "byteSize" => upload.byte_size,
        "url" => Messngr.Media.Storage.public_url(upload.bucket, upload.object_key)
      }
    }
    |> merge_metadata(upload.metadata)
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
end
