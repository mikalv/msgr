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
          expires_at: instructions["expiresAt"]
        }
      }
    }
  end
end
