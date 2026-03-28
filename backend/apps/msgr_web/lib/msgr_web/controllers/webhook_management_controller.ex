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
          created_by_account_id: account.id,
          template: params["template"],
          template_preset: params["template_preset"]
        }

        case WebhookEndpoint.create(attrs) do
          {:ok, endpoint} ->
            host = Application.get_env(:msgr_web, :invite_host, "dev.msgr.no")

            conn
            |> put_status(:created)
            |> json(%{
              data: %{
                id: endpoint.id,
                name: endpoint.name,
                channel_id: endpoint.channel_id,
                token: endpoint.token,
                url: "https://#{host}/api/hooks/#{endpoint.token}",
                enabled: endpoint.enabled,
                message_count: endpoint.message_count,
                template: endpoint.template,
                template_preset: endpoint.template_preset,
                inserted_at: endpoint.inserted_at
              }
            })

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

    json(conn, %{
      data:
        Enum.map(endpoints, fn e ->
          %{
            id: e.id,
            name: e.name,
            channel_id: e.channel_id,
            token: e.token,
            url: "https://#{host}/api/hooks/#{e.token}",
            enabled: e.enabled,
            message_count: e.message_count,
            template: e.template,
            template_preset: e.template_preset,
            inserted_at: e.inserted_at
          }
        end)
    })
  end

  @doc "PUT /api/teams/:slug/webhooks/:id — update a webhook"
  def update(conn, %{"id" => id} = params) do
    case Messngr.Repo.get(WebhookEndpoint, id) do
      nil ->
        {:error, :not_found}

      endpoint ->
        attrs = %{}
        attrs = if params["name"], do: Map.put(attrs, :name, params["name"]), else: attrs

        attrs =
          if params["template"], do: Map.put(attrs, :template, params["template"]), else: attrs

        attrs =
          if Map.has_key?(params, "template_preset"),
            do: Map.put(attrs, :template_preset, params["template_preset"]),
            else: attrs

        case endpoint |> WebhookEndpoint.changeset(attrs) |> Messngr.Repo.update() do
          {:ok, updated} ->
            json(conn, %{
              data: %{
                id: updated.id,
                template: updated.template,
                template_preset: updated.template_preset
              }
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc "GET /api/teams/:slug/webhooks/presets — list available template presets"
  def presets(conn, _params) do
    json(conn, %{data: Messngr.Webhooks.TemplateEngine.preset_names()})
  end

  @doc "DELETE /api/teams/:slug/webhooks/:id — delete a webhook"
  def delete(conn, %{"id" => id}) do
    case WebhookEndpoint.delete(id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
