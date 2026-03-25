defmodule MessngrWeb.WebhookManagementController do
  @moduledoc """
  CRUD for webhook endpoints. Restricted to team owner/admin.
  """

  use MessngrWeb, :controller

  alias Messngr.Teams.WebhookEndpoint
  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/webhooks — create a webhook for a channel"
  def create(conn, params) do
    account = conn.assigns.current_account
    team = conn.assigns.current_team
    prefix = conn.assigns.tenant_prefix

    # Check admin/owner role
    case TeamManagement.get_membership(team.id, account.id) do
      nil ->
        {:error, :forbidden}

      membership when membership.role not in ["owner", "admin"] ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only team owners and admins can create webhooks"})

      _membership ->
        attrs = %{
          team_id: team.id,
          channel_id: params["channel_id"],
          name: params["name"] || "Webhook",
          avatar_url: params["avatar_url"],
          created_by_account_id: account.id
        }

        case WebhookEndpoint.create(attrs) do
          {:ok, endpoint} ->
            host = Application.get_env(:msgr_web, :invite_host, "dev.msgr.no")

            conn
            |> put_status(:created)
            |> json(%{data: %{
              id: endpoint.id,
              name: endpoint.name,
              channel_id: endpoint.channel_id,
              token: endpoint.token,
              url: "https://#{host}/api/hooks/#{endpoint.token}",
              enabled: endpoint.enabled,
              message_count: endpoint.message_count,
              inserted_at: endpoint.inserted_at
            }})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc "GET /api/teams/:slug/webhooks — list webhooks"
  def index(conn, _params) do
    team = conn.assigns.current_team
    host = Application.get_env(:msgr_web, :invite_host, "dev.msgr.no")
    endpoints = WebhookEndpoint.list_for_team(team.id)

    json(conn, %{data: Enum.map(endpoints, fn e ->
      %{
        id: e.id,
        name: e.name,
        channel_id: e.channel_id,
        token: e.token,
        url: "https://#{host}/api/hooks/#{e.token}",
        enabled: e.enabled,
        message_count: e.message_count,
        inserted_at: e.inserted_at
      }
    end)})
  end

  @doc "DELETE /api/teams/:slug/webhooks/:id — delete a webhook"
  def delete(conn, %{"id" => id}) do
    case WebhookEndpoint.delete(id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
