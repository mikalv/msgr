defmodule MessngrWeb.MediaUploadController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def create(conn, %{"id" => conversation_id, "upload" => upload_params}) do
    current_profile = conn.assigns.current_profile

    with _ <- Messngr.ensure_membership(conversation_id, current_profile.id),
         {:ok, upload, instructions} <-
           Messngr.create_media_upload(conversation_id, current_profile.id, upload_params) do
      conn
      |> put_status(:created)
      |> render(:show, upload: upload, instructions: instructions)
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(_conn, _params), do: {:error, :bad_request}
end
