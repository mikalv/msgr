defmodule MessngrWeb.CommandController do
  use MessngrWeb, :controller

  alias Messngr.Apps

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/channels/:channel_id/commands"
  def execute(conn, %{"channel_id" => channel_id} = params) do
    team = conn.assigns.current_team
    account = conn.assigns.current_account
    prefix = conn.assigns.tenant_prefix

    command_name = params["command"]
    args = params["args"]

    unless is_binary(command_name) and command_name != "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "command is required"})
    else
      case Apps.lookup_command(team.id, command_name) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "unknown_command", command: command_name})

        {app, slash_command} ->
          command = %{
            command: command_name,
            args: args,
            channel_id: channel_id,
            triggered_by: account.id
          }

          context = %{
            team_id: team.id,
            tenant_prefix: prefix,
            app: app,
            installation: get_installation(app, team.id),
            config: %{}
          }

          result = dispatch_command(app, slash_command, command, context)

          case result do
            {:ok, %{type: :message, content: content} = response} ->
              # Post result as a system message in the channel
              maybe_post_system_message(prefix, channel_id, content)

              json(conn, %{
                data: %{
                  command: command_name,
                  app: app.slug,
                  status: "completed",
                  result: %{
                    type: "message",
                    content: content
                  }
                }
              })

            {:ok, response} ->
              json(conn, %{
                data: %{
                  command: command_name,
                  app: app.slug,
                  status: "completed",
                  result: response
                }
              })

            {:error, reason} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "command_failed", reason: to_string(reason)})
          end
      end
    end
  end

  # ── Command list endpoint ──────────────────────────────────────

  @doc "GET /api/teams/:slug/commands — list available commands for team"
  def index(conn, _params) do
    team = conn.assigns.current_team
    commands = Apps.list_commands_for_team(team.id)

    json(conn, %{
      data: Enum.map(commands, fn cmd ->
        %{
          name: cmd.name,
          description: cmd.description,
          permissions: cmd.permissions,
          app_slug: cmd.app_slug,
          app_name: cmd.app_name
        }
      end)
    })
  end

  # ── Dispatcher ─────────────────────────────────────────────────

  defp dispatch_command(%{executor_type: "builtin"} = _app, slash_command, command, context) do
    executor = executor_for_builtin(slash_command.name)

    if executor do
      executor.execute(command, context)
    else
      {:ok, %{
        type: :message,
        content: "Kommando /#{slash_command.name} er ikke implementert ennå"
      }}
    end
  end

  defp dispatch_command(%{executor_type: "llm"} = _app, _slash_command, command, context) do
    Messngr.Apps.Executors.LlmExecutor.execute(command, context)
  end

  defp dispatch_command(%{executor_type: "webhook"} = _app, slash_command, _command, _context) do
    {:ok, %{
      message: "Webhook-kommando /#{slash_command.name} sendt",
      command: slash_command.name,
      executor: "webhook",
      status: "dispatched"
    }}
  end

  defp dispatch_command(_app, slash_command, _command, _context) do
    {:ok, %{
      message: "Kommando /#{slash_command.name} er ikke implementert ennå",
      command: slash_command.name,
      executor: "unknown"
    }}
  end

  # ── Built-in executor routing ──────────────────────────────────

  defp executor_for_builtin("poll"), do: Messngr.Apps.Executors.PollExecutor
  defp executor_for_builtin("remind"), do: Messngr.Apps.Executors.RemindExecutor
  defp executor_for_builtin("topic"), do: Messngr.Apps.Executors.TopicExecutor
  defp executor_for_builtin(_), do: nil

  # ── Helpers ────────────────────────────────────────────────────

  defp get_installation(%{executor_type: "builtin"}, _team_id), do: nil

  defp get_installation(app, team_id) do
    Apps.get_installation_by_app_slug(app.slug, team_id)
  end

  defp maybe_post_system_message(prefix, channel_id, content) do
    # Post the command result as a system message in the channel.
    # sender_profile_id is nil (system), content includes system: true marker.
    try do
      Teams.TenantModels.Message.create(prefix, %{
        channel_id: channel_id,
        content: %{"text" => content, "system" => true}
      })
    rescue
      _ -> :ok
    end
  end
end
