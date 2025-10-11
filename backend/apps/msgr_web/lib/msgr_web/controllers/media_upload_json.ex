defmodule MessngrWeb.MediaUploadJSON do
  alias Messngr.Media.Upload

  def show(%{upload: %Upload{} = upload, instructions: instructions}) do
    %{
      data: %{
        id: upload.id,
        kind: upload.kind |> to_string(),
        status: upload.status |> to_string(),
        bucket: upload.bucket,
        object_key: upload.object_key,
        content_type: upload.content_type,
        byte_size: upload.byte_size,
        expires_at: upload.expires_at,
        upload: %{
          method: instructions["method"],
          url: instructions["url"],
          headers: instructions["headers"],
          bucket: instructions["bucket"],
          object_key: instructions["objectKey"],
          public_url: instructions["publicUrl"],
          expires_at: instructions["expiresAt"],
          retention_expires_at: instructions["retentionExpiresAt"],
          thumbnail_upload: encode_thumbnail(instructions["thumbnailUpload"])
        }
          method: instructions["upload"]["method"],
          url: instructions["upload"]["url"],
          headers: instructions["upload"]["headers"],
          expires_at: instructions["upload"]["expiresAt"]
        },
        download: %{
          method: instructions["download"]["method"],
          url: instructions["download"]["url"],
          expires_at: instructions["download"]["expiresAt"]
        },
        public_url: instructions["publicUrl"],
        retention_until: instructions["retentionUntil"]
      }
    }
  end

  defp encode_thumbnail(nil), do: nil

  defp encode_thumbnail(%{} = thumbnail) do
    %{
      method: thumbnail["method"],
      url: thumbnail["url"],
      headers: thumbnail["headers"],
      bucket: thumbnail["bucket"],
      object_key: thumbnail["objectKey"],
      public_url: thumbnail["publicUrl"],
      expires_at: thumbnail["expiresAt"]
    }
  end
end
