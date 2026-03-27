defmodule MessngrWeb.AppController do
  use MessngrWeb, :controller

  alias Messngr.Apps
  alias Messngr.Apps.App

  action_fallback MessngrWeb.FallbackController

  # ── Public app endpoints ──────────────────────────────────────

  @doc "GET /api/apps — list available apps"
  def index(conn, _params) do
    apps = Apps.list_apps()
    json(conn, %{data: Enum.map(apps, &app_json/1)})
  end

  @doc "POST /api/apps — create an app (developer)"
  def create(conn, params) do
    account = conn.assigns.current_account

    attrs = %{
      slug: params["slug"],
      name: params["name"],
      description: params["description"],
      icon_url: params["icon_url"],
      developer_id: account.id,
      executor_type: params["executor_type"] || "builtin",
      manifest: params["manifest"] || %{},
      visibility: params["visibility"] || "private",
      webhook_url: params["webhook_url"],
      webhook_secret: params["webhook_secret"]
    }

    case Apps.create_app(attrs) do
      {:ok, app} ->
        # Register slash commands from manifest if provided
        register_commands_from_params(app, params["commands"])

        conn
        |> put_status(:created)
        |> json(%{data: app_json(app)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ── Team-scoped app endpoints ─────────────────────────────────

  @doc "GET /api/teams/:slug/apps — list installed apps for team"
  def team_index(conn, _params) do
    team = conn.assigns.current_team
    installations = Apps.list_installations_for_team(team.id)

    json(conn, %{
      data:
        Enum.map(installations, fn inst ->
          %{
            id: inst.id,
            app: app_json(inst.app),
            status: inst.status,
            config: inst.config,
            installed_at: inst.installed_at
          }
        end)
    })
  end

  @doc "POST /api/teams/:slug/apps/:app_slug/install — install app"
  def install(conn, %{"app_slug" => app_slug} = params) do
    team = conn.assigns.current_team

    case Apps.get_app_by_slug(app_slug) do
      nil ->
        {:error, :not_found}

      app ->
        config = params["config"] || %{}

        case Apps.install_app(app.id, team.id, config) do
          {:ok, installation} ->
            conn
            |> put_status(:created)
            |> json(%{
              data: %{
                id: installation.id,
                app_slug: app.slug,
                status: installation.status,
                installed_at: installation.installed_at
              }
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc "DELETE /api/teams/:slug/apps/:app_slug — uninstall app"
  def uninstall(conn, %{"app_slug" => app_slug}) do
    team = conn.assigns.current_team

    case Apps.get_installation_by_app_slug(app_slug, team.id) do
      nil ->
        {:error, :not_found}

      installation ->
        case Apps.uninstall_app(installation.id) do
          {:ok, _} -> json(conn, %{data: %{uninstalled: true}})
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc "POST /api/teams/:slug/apps/:app_slug/tokens — generate bot token"
  def create_token(conn, %{"app_slug" => app_slug} = params) do
    team = conn.assigns.current_team
    label = params["label"] || "default"
    scopes = params["scopes"] || []

    case Apps.get_installation_by_app_slug(app_slug, team.id) do
      nil ->
        {:error, :not_found}

      installation ->
        case Apps.generate_bot_token(installation.id, label, scopes) do
          {:ok, raw_token, record} ->
            conn
            |> put_status(:created)
            |> json(%{
              data: %{
                id: record.id,
                token: raw_token,
                label: record.label,
                scopes: record.scopes,
                expires_at: record.expires_at
              },
              warning: "Lagre token nå — den vises ikke igjen."
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc "GET /api/teams/:slug/apps/:app_slug/tokens — list tokens"
  def list_tokens(conn, %{"app_slug" => app_slug}) do
    team = conn.assigns.current_team

    case Apps.get_installation_by_app_slug(app_slug, team.id) do
      nil -> {:error, :not_found}
      installation ->
        tokens = Apps.list_bot_tokens(installation.id)
        json(conn, %{data: Enum.map(tokens, fn t ->
          %{
            id: t.id,
            label: t.label,
            scopes: t.scopes,
            last_used_at: t.last_used_at,
            expires_at: t.expires_at,
            inserted_at: t.inserted_at
          }
        end)})
    end
  end

  @doc "DELETE /api/teams/:slug/apps/:app_slug/tokens/:token_id — revoke token"
  def revoke_token(conn, %{"token_id" => token_id}) do
    case Apps.revoke_bot_token(token_id) do
      {:ok, _} -> json(conn, %{data: %{revoked: true}})
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp app_json(%App{} = app) do
    %{
      id: app.id,
      slug: app.slug,
      name: app.name,
      description: app.description,
      icon_url: app.icon_url,
      executor_type: app.executor_type,
      visibility: app.visibility,
      status: app.status,
      inserted_at: app.inserted_at
    }
  end

  defp register_commands_from_params(_app, nil), do: :ok
  defp register_commands_from_params(_app, commands) when not is_list(commands), do: :ok

  defp register_commands_from_params(app, commands) do
    for cmd <- commands do
      Apps.create_command(app.id, %{
        name: cmd["name"],
        description: cmd["description"],
        args_schema: cmd["args_schema"],
        permissions: cmd["permissions"] || "member"
      })
    end
  end
end
