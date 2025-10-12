defmodule MessngrWeb.MediaUploadJSON do
  alias Messngr.Media.Upload

  def show(%{upload: %Upload{} = upload, instructions: instructions}) do
    %{
      data: %{
        id: upload.id,
        kind: to_string(upload.kind),
        status: to_string(upload.status),
        bucket: upload.bucket,
        object_key: upload.object_key,
        content_type: upload.content_type,
        byte_size: upload.byte_size,
        expires_at: upload.expires_at,
        upload: encode_upload_instructions(instructions),
        download: encode_download(instructions["download"]),
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

  defp encode_upload_instructions(nil), do: nil

  defp encode_upload_instructions(instructions) when is_map(instructions) do
    %{
      method: instructions["method"],
      url: instructions["url"],
      headers: instructions["headers"],
      bucket: instructions["bucket"],
      object_key: instructions["objectKey"],
      public_url: instructions["publicUrl"],
      expires_at: instructions["expiresAt"],
      retention_expires_at: instructions["retentionExpiresAt"],
      thumbnail_upload: encode_thumbnail(instructions["thumbnailUpload"]),
      multipart: encode_multipart(instructions["upload"])
    }
  end

  defp encode_multipart(nil), do: nil

  defp encode_multipart(%{} = upload) do
    %{
      method: upload["method"],
      url: upload["url"],
      headers: upload["headers"],
      expires_at: upload["expiresAt"]
    }
  end

  defp encode_download(nil), do: nil

  defp encode_download(%{} = download) do
    %{
      method: download["method"],
      url: download["url"],
      expires_at: download["expiresAt"]
    }
  end
end
