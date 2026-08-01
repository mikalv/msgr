defmodule MessngrWeb.InviteLinkController do
  use MessngrWeb, :controller

  alias Messngr.Teams.InviteLink
  alias MessngrWeb.TeamAuth

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/invites — generate a new invite link"
  def create(conn, _params) do
    with :ok <- TeamAuth.require_team_admin(conn) do
      account = conn.assigns.current_account
      team = conn.assigns.current_team

      case InviteLink.create(team.id, account.id) do
        {:ok, link} ->
          conn
          |> put_status(:created)
          |> json(%{data: link_json(link, conn)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "GET /api/teams/:slug/invites — list active invite links"
  def index(conn, _params) do
    with :ok <- TeamAuth.require_team_admin(conn) do
      team = conn.assigns.current_team
      links = InviteLink.list_active(team.id)

      json(conn, %{data: Enum.map(links, &link_json(&1, conn))})
    end
  end

  @doc "DELETE /api/teams/:slug/invites/:id — revoke an invite link"
  def delete(conn, %{"id" => id}) do
    with :ok <- TeamAuth.require_team_admin(conn) do
      team = conn.assigns.current_team

      case Messngr.Repo.get(InviteLink, id) do
        nil ->
          {:error, :not_found}

        %{team_id: team_id} when team_id != team.id ->
          {:error, :forbidden}

        link ->
          case InviteLink.revoke(link.id) do
            {:ok, _} -> send_resp(conn, :no_content, "")
            {:error, :not_found} -> {:error, :not_found}
          end
      end
    end
  end

  defp link_json(link, _conn) do
    host = Application.get_env(:msgr_web, :invite_host, "dev.msgr.no")

    %{
      id: link.id,
      code: link.code,
      url: "https://#{host}/invite/#{link.code}",
      expires_at: link.expires_at,
      used_count: link.used_count,
      inserted_at: link.inserted_at
    }
  end
end
