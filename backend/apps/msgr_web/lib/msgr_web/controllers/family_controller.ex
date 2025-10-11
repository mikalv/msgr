defmodule MessngrWeb.FamilyController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, _params) do
    current_profile = conn.assigns.current_profile
    families = Messngr.list_families(current_profile.id)

    render(conn, :index, families: families)
  end

  def create(conn, %{"family" => family_params}) do
    current_profile = conn.assigns.current_profile

    with {:ok, family} <- Messngr.create_family(current_profile.id, family_params) do
      conn
      |> put_status(:created)
      |> render(:show, family: family)
    end
  end

  def show(conn, %{"id" => family_id}) do
    current_profile = conn.assigns.current_profile

    with _membership <- Messngr.ensure_family_membership(family_id, current_profile.id),
         family <- Messngr.get_family!(family_id) do
      render(conn, :show, family: family)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(_conn, _params), do: {:error, :bad_request}
end
