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
end
