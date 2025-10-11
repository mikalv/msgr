defmodule MessngrWeb.FamilyTodoListController do
  use MessngrWeb, :controller

  alias FamilySpace

  action_fallback MessngrWeb.FallbackController

  def index(conn, %{"family_id" => family_id} = params) do
    current_profile = conn.assigns.current_profile
    include_archived? = Map.get(params, "include_archived") in [true, "true", "1", 1]

    with _ <- FamilySpace.ensure_membership(family_id, current_profile.id) do
      lists = FamilySpace.list_todo_lists(family_id, include_archived: include_archived?)
      render(conn, :index, lists: lists)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(conn, %{"family_id" => family_id, "list" => list_params}) do
    current_profile = conn.assigns.current_profile

    attrs = Map.new(list_params)

    with {:ok, list} <- FamilySpace.create_todo_list(family_id, current_profile.id, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, list: list)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def show(conn, %{"family_id" => family_id, "id" => list_id}) do
    current_profile = conn.assigns.current_profile

    with _ <- FamilySpace.ensure_membership(family_id, current_profile.id),
         list <- FamilySpace.get_todo_list!(family_id, list_id) do
      render(conn, :show, list: list)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def update(conn, %{"family_id" => family_id, "id" => list_id, "list" => list_params}) do
    current_profile = conn.assigns.current_profile

    attrs = Map.new(list_params)

    with {:ok, list} <- FamilySpace.update_todo_list(family_id, list_id, current_profile.id, attrs) do
      render(conn, :show, list: list)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def delete(conn, %{"family_id" => family_id, "id" => list_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, _} <- FamilySpace.delete_todo_list(family_id, list_id, current_profile.id) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end
end
