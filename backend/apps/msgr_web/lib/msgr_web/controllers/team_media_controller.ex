defmodule MessngrWeb.TeamMediaController do
  use MessngrWeb, :controller

  alias Teams.TeamManagement
  alias Teams.TenantModels.MediaUpload

  action_fallback MessngrWeb.FallbackController

  @max_file_size 50 * 1024 * 1024  # 50 MB

  @doc "POST /api/teams/:slug/media/presign — presigned upload URL"
  def presign(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account
    team = conn.assigns.current_team

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      filename = params["filename"] || "upload"
      content_type = params["content_type"] || "application/octet-stream"
      size = params["size"]

      if is_integer(size) and size > @max_file_size do
        conn
        |> put_status(:request_entity_too_large)
        |> json(%{error: "file_too_large", max_size: @max_file_size})
      else
        # Generate a unique object key
        object_key = "teams/#{team.id}/#{Ecto.UUID.generate()}/#{filename}"

        # Record the upload in the tenant schema
        {:ok, upload} =
          MediaUpload.create(prefix, %{
            profile_id: profile.id,
            object_key: object_key,
            content_type: content_type,
            filename: filename,
            size: size
          })

        # Generate presigned URL (MinIO/S3-compatible)
        presigned_url = generate_presigned_url(object_key, content_type)

        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            upload_id: upload.id,
            object_key: object_key,
            presigned_url: presigned_url,
            expires_in: 3600
          }
        })
      end
    end
  end

  defp generate_presigned_url(object_key, content_type) do
    # In production this would use ExAws or similar to generate a real presigned URL.
    # For now, return a placeholder that the gateway/MinIO integration will fulfill.
    bucket = Application.get_env(:msgr, :minio_bucket, "msgr-uploads")
    host = Application.get_env(:msgr, :minio_host, "localhost:9000")
    "http://#{host}/#{bucket}/#{object_key}?content-type=#{URI.encode(content_type)}"
  end
end
