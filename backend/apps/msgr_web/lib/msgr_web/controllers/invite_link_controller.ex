defmodule MessngrWeb.InviteLinkController do
  use MessngrWeb, :controller

  alias Messngr.Teams.InviteLink

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/invites — generate a new invite link"
  def create(conn, _params) do
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

  @doc "GET /api/teams/:slug/invites — list active invite links"
  def index(conn, _params) do
    team = conn.assigns.current_team
    links = InviteLink.list_active(team.id)

    json(conn, %{data: Enum.map(links, &link_json(&1, conn))})
  end

  @doc "DELETE /api/teams/:slug/invites/:id — revoke an invite link"
  def delete(conn, %{"id" => id}) do
    case InviteLink.revoke(id) do
      {:ok, _link} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> {:error, :not_found}
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
