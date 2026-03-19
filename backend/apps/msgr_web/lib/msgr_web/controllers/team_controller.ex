defmodule MessngrWeb.TeamController do
  use MessngrWeb, :controller

  alias Messngr.Teams

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams — list teams for current account"
  def index(conn, _params) do
    account = conn.assigns.current_actor
    teams = Teams.list_teams_for_account(account.id)
    json(conn, %{data: Enum.map(teams, &team_json/1)})
  end

  @doc "POST /api/teams — create a new team"
  def create(conn, params) do
    account = conn.assigns.current_actor

    attrs = %{
      name: params["name"],
      slug: params["slug"],
      owner_account_id: account.id
    }

    case Teams.create_team(attrs) do
      {:ok, team} ->
        conn
        |> put_status(:created)
        |> json(%{data: team_json(team)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc "POST /api/teams/:slug/join — join a team"
  def join(conn, %{"slug" => slug}) do
    account = conn.assigns.current_actor

    case Teams.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        case Teams.join_team(team, account.id, %{
               display_name: account.handle || account.email
             }) do
          {:ok, result} ->
            conn
            |> put_status(:created)
            |> json(%{data: %{team: team_json(team), profile_id: result.profile.id}})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  defp team_json(team) do
    %{
      id: team.id,
      name: team.name,
      slug: team.slug,
      domain: team.domain,
      settings: team.settings,
      inserted_at: team.inserted_at
    }
  end
end
