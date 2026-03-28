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

  @doc "PATCH /api/teams/:slug — update team settings (owner/admin only)"
  def update(conn, %{"slug" => slug} = params) do
    account = conn.assigns.current_account

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        case TeamManagement.get_membership(team.id, account.id) do
          nil ->
            {:error, :forbidden}

          m when m.role not in ["owner", "admin"] ->
            {:error, :forbidden}

          _m ->
            attrs = %{}
            attrs = if params["name"], do: Map.put(attrs, :name, params["name"]), else: attrs

            attrs =
              if params["settings"],
                do: Map.put(attrs, :settings, params["settings"]),
                else: attrs

            case TeamManagement.update_team(team, attrs) do
              {:ok, updated} -> json(conn, %{data: team_json(updated)})
              {:error, changeset} -> {:error, changeset}
            end
        end
    end
  end

  @doc "PUT /api/teams/:slug/members/:account_id/role — change member role (owner only)"
  def change_role(conn, %{"slug" => slug, "account_id" => target_account_id} = params) do
    account = conn.assigns.current_account

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        case TeamManagement.get_membership(team.id, account.id) do
          nil ->
            {:error, :forbidden}

          m when m.role != "owner" ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Only the team owner can change roles"})

          _owner ->
            new_role = params["role"]

            if new_role not in ["admin", "member"] do
              conn |> put_status(:bad_request) |> json(%{error: "Role must be admin or member"})
            else
              case TeamManagement.change_role(team.id, target_account_id, new_role) do
                {:ok, _} -> json(conn, %{ok: true})
                {:error, :not_found} -> {:error, :not_found}
                {:error, changeset} -> {:error, changeset}
              end
            end
        end
    end
  end

  @doc "DELETE /api/teams/:slug/members/:account_id — remove member (owner/admin only)"
  def remove_member(conn, %{"slug" => slug, "account_id" => target_account_id}) do
    account = conn.assigns.current_account

    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        case TeamManagement.get_membership(team.id, account.id) do
          nil ->
            {:error, :forbidden}

          m when m.role not in ["owner", "admin"] ->
            {:error, :forbidden}

          _m ->
            # Prevent removing the owner
            target = TeamManagement.get_membership(team.id, target_account_id)

            if target && target.role == "owner" do
              conn |> put_status(:forbidden) |> json(%{error: "Cannot remove the team owner"})
            else
              case TeamManagement.remove_member(team, target_account_id) do
                {:ok, _} -> send_resp(conn, :no_content, "")
                {:error, :not_found} -> {:error, :not_found}
              end
            end
        end
    end
  end

  @doc "GET /api/teams/:slug/members — list team members with roles"
  def members(conn, %{"slug" => slug}) do
    case TeamManagement.get_team_by_slug(slug) do
      nil ->
        {:error, :not_found}

      team ->
        prefix = team.schema_name
        memberships = TeamManagement.list_members(team.id)

        # Enrich with profile display names from tenant schema
        members =
          Enum.map(memberships, fn m ->
            profile = TeamManagement.get_profile_for_account(prefix, m.account_id)

            %{
              account_id: m.account_id,
              role: m.role,
              joined_at: m.joined_at,
              profile_id: profile && profile.id,
              display_name: profile && profile.display_name,
              avatar_url: profile && profile.avatar_url
            }
          end)

        json(conn, %{data: members})
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
