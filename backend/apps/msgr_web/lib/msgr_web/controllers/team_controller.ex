defmodule MessngrWeb.TeamController do
  use MessngrWeb, :controller

  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams — list teams for current account"
  def index(conn, _params) do
    account = conn.assigns.current_account
    teams = TeamManagement.list_teams_for_account(account.id)
    json(conn, %{data: Enum.map(teams, &team_json/1)})
  end

  @doc "POST /api/teams — create a new team"
  def create(conn, params) do
    account = conn.assigns.current_account

    attrs = %{
      name: params["name"],
      slug: params["slug"],
      owner_account_id: account.id
    }

    case TeamManagement.create_team(attrs) do
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
    account = conn.assigns.current_account

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        case TeamManagement.join_team(team, account.id, %{
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
