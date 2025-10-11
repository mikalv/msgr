defmodule MessngrWeb.FamilyNoteController do
  use MessngrWeb, :controller

  alias FamilySpace

  action_fallback MessngrWeb.FallbackController

  def index(conn, %{"family_id" => family_id} = params) do
    current_profile = conn.assigns.current_profile
    pinned_only? = Map.get(params, "pinned_only") in [true, "true", "1", 1]

    with _ <- FamilySpace.ensure_membership(family_id, current_profile.id) do
      notes = FamilySpace.list_notes(family_id, pinned_only: pinned_only?)
      render(conn, :index, notes: notes)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(conn, %{"family_id" => family_id, "note" => note_params}) do
    current_profile = conn.assigns.current_profile
    attrs = Map.new(note_params)

    with {:ok, note} <- FamilySpace.create_note(family_id, current_profile.id, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, note: note)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def show(conn, %{"family_id" => family_id, "id" => note_id}) do
    current_profile = conn.assigns.current_profile

    with _ <- FamilySpace.ensure_membership(family_id, current_profile.id),
         note <- FamilySpace.get_note!(family_id, note_id) do
      render(conn, :show, note: note)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def update(conn, %{"family_id" => family_id, "id" => note_id, "note" => note_params}) do
    current_profile = conn.assigns.current_profile
    attrs = Map.new(note_params)

    with {:ok, note} <- FamilySpace.update_note(family_id, note_id, current_profile.id, attrs) do
      render(conn, :show, note: note)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def delete(conn, %{"family_id" => family_id, "id" => note_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, _} <- FamilySpace.delete_note(family_id, note_id, current_profile.id) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end
end
