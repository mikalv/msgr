defmodule MessngrWeb.TeamMediaController do
  use MessngrWeb, :controller

  alias Teams.TeamManagement
  alias Teams.TenantModels.MediaUpload
  alias Messngr.Media.Storage

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
              size: size
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
              expires_at: DateTime.to_iso8601(expires_at)
            }
          })
      end
    end
  end

  @doc "GET /api/teams/:slug/media/:object_key/url — presigned download URL"
  def download_url(conn, %{"object_key" => object_key_encoded}) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      object_key = URI.decode(object_key_encoded)
      bucket = Storage.bucket()

      %{url: url, expires_at: expires_at} =
        Storage.presign_download(bucket, object_key)

      conn
      |> json(%{
        data: %{
          download_url: url,
          expires_at: DateTime.to_iso8601(expires_at)
        }
      })
    end
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
