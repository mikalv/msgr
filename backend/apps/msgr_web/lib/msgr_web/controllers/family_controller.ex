defmodule MessngrWeb.FamilyController do
  use MessngrWeb, :controller

  alias FamilySpace

  action_fallback MessngrWeb.FallbackController

  def index(conn, _params) do
    current_profile = conn.assigns.current_profile
    families = FamilySpace.list_spaces(current_profile.id, kind: :family)

    render(conn, :index, families: families)
  end

  def create(conn, %{"family" => family_params}) do
    current_profile = conn.assigns.current_profile

    attrs = Map.put_new(family_params, :kind, :family)

    with {:ok, family} <- FamilySpace.create_space(current_profile.id, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, family: family)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def show(conn, %{"id" => family_id}) do
    current_profile = conn.assigns.current_profile

    with _membership <- FamilySpace.ensure_membership(family_id, current_profile.id),
         family <- FamilySpace.get_space!(family_id) do
      render(conn, :show, family: family)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end
end
