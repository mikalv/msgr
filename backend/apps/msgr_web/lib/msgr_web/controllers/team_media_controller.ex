defmodule MessngrWeb.TeamMediaController do
  use MessngrWeb, :controller

  alias Messngr.Media.Storage
  alias Messngr.Media.VirusScan
  alias Teams.TenantModels.MediaUpload

  action_fallback MessngrWeb.FallbackController

  # 50 MB
  @max_file_size 50 * 1024 * 1024

  @doc "POST /api/teams/:slug/media/presign — presigned upload URL"
  def presign(conn, params) do
    prefix = conn.assigns.tenant_prefix
    profile = conn.assigns.current_team_profile
    team = conn.assigns.current_team

    filename = params["filename"] || "upload"
    content_type = params["content_type"] || "application/octet-stream"
    size = parse_size(params["size"])

    cond do
      is_integer(size) and size > @max_file_size ->
        conn
        |> put_status(:request_entity_too_large)
        |> json(%{error: "file_too_large", max_size: @max_file_size})

      is_integer(size) and size <= 0 ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_size"})

      true ->
        # Generate a unique object key
        object_key = "teams/#{team.id}/#{Ecto.UUID.generate()}/#{filename}"
        bucket = Storage.bucket()

        # Record the upload in the tenant schema
        {:ok, upload} =
          MediaUpload.create(prefix, %{
            profile_id: profile.id,
            object_key: object_key,
            content_type: content_type,
            filename: filename,
            size: size,
            scan_status: :awaiting_upload
          })

        # Generate presigned upload URL via Storage module
        %{url: upload_url, expires_at: expires_at, headers: headers} =
          Storage.presign_upload(bucket, object_key, content_type: content_type)

        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            upload_id: upload.id,
            object_key: object_key,
            upload_url: upload_url,
            upload_headers: headers,
            upload_method: "PUT",
            scan_status: upload.scan_status,
            expires_at: DateTime.to_iso8601(expires_at)
          }
        })
    end
  end

  @doc """
  POST /api/teams/:slug/media/:upload_id/complete — client finished PUT to MinIO.

  Enqueues virus scan (or marks clean when scanning is disabled).
  """
  def complete(conn, %{"upload_id" => upload_id}) do
    prefix = conn.assigns.tenant_prefix
    profile = conn.assigns.current_team_profile

    case MediaUpload.get_by_id(prefix, upload_id) do
      nil ->
        {:error, :not_found}

      %MediaUpload{profile_id: profile_id} = upload when profile_id != profile.id ->
        {:error, :forbidden}

      %MediaUpload{scan_status: status} = upload
      when status in [:scanning, :clean, :infected] ->
        json(conn, %{data: upload_json(upload)})

      %MediaUpload{} = upload ->
        case VirusScan.complete_upload(prefix, upload) do
          {:ok, updated} ->
            json(conn, %{data: upload_json(updated)})

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc "GET /api/teams/:slug/media/:object_key/url — presigned download URL"
  def download_url(conn, %{"object_key" => object_key_encoded}) do
    prefix = conn.assigns.tenant_prefix
    team = conn.assigns.current_team
    object_key = URI.decode(object_key_encoded)
    team_prefix = "teams/#{team.id}/"

    with :ok <- validate_team_prefix(object_key, team_prefix),
         {:ok, upload} <- fetch_upload(prefix, object_key),
         :ok <- VirusScan.authorize_download(upload) do
      bucket = Storage.bucket()

      %{url: url, expires_at: expires_at} =
        Storage.presign_download(bucket, object_key)

      json(conn, %{
        data: %{
          download_url: url,
          expires_at: DateTime.to_iso8601(expires_at),
          scan_status: upload.scan_status
        }
      })
    end
  end

  defp validate_team_prefix(object_key, team_prefix) do
    if String.starts_with?(object_key, team_prefix), do: :ok, else: {:error, :forbidden}
  end

  defp fetch_upload(prefix, object_key) do
    case MediaUpload.get_by_object_key(prefix, object_key) do
      nil -> {:error, :not_found}
      upload -> {:ok, upload}
    end
  end

  defp upload_json(upload) do
    %{
      upload_id: upload.id,
      object_key: upload.object_key,
      scan_status: upload.scan_status,
      threat_name: upload.threat_name,
      scanned_at: upload.scanned_at && DateTime.to_iso8601(upload.scanned_at)
    }
  end

  defp parse_size(nil), do: nil
  defp parse_size(size) when is_integer(size), do: size

  defp parse_size(size) when is_binary(size) do
    case Integer.parse(size) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_size(_), do: nil
end
