defmodule MessngrWeb.FamilyTodoItemController do
  use MessngrWeb, :controller

  alias FamilySpace

  action_fallback MessngrWeb.FallbackController

  def index(conn, %{"family_id" => family_id, "todo_list_id" => list_id}) do
    current_profile = conn.assigns.current_profile

    with _ <- FamilySpace.ensure_membership(family_id, current_profile.id),
         list <- FamilySpace.get_todo_list!(family_id, list_id) do
      render(conn, :index, list: list)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(conn, %{"family_id" => family_id, "todo_list_id" => list_id, "item" => params}) do
    current_profile = conn.assigns.current_profile

    with {:ok, item} <- FamilySpace.add_todo_item(family_id, list_id, current_profile.id, params) do
      conn
      |> put_status(:created)
      |> render(:show, item: item)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def update(conn, %{"family_id" => family_id, "todo_list_id" => list_id, "id" => item_id, "item" => params}) do
    current_profile = conn.assigns.current_profile

    with {:ok, item} <-
           FamilySpace.update_todo_item(family_id, list_id, item_id, current_profile.id, params) do
      render(conn, :show, item: item)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def delete(conn, %{"family_id" => family_id, "todo_list_id" => list_id, "id" => item_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, _} <- FamilySpace.delete_todo_item(family_id, list_id, item_id, current_profile.id) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end
end
