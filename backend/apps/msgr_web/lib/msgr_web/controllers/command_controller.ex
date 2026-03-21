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
          # Log the execution (could be expanded to write to tenant command_executions)
          result = dispatch_command(app, slash_command, %{
            command: command_name,
            args: args,
            channel_id: channel_id,
            triggered_by: account.id,
            team_id: team.id,
            tenant_prefix: prefix
          })

          case result do
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

  # Dispatch to the correct executor based on app type.
  # For now, builtin commands return a placeholder response.
  defp dispatch_command(%{executor_type: "builtin"} = _app, command, context) do
    {:ok, %{
      message: "Kommando /#{command.name} mottatt",
      command: command.name,
      args: context.args,
      executor: "builtin"
    }}
  end

  defp dispatch_command(%{executor_type: "webhook"} = _app, command, _context) do
    {:ok, %{
      message: "Webhook-kommando /#{command.name} sendt",
      command: command.name,
      executor: "webhook",
      status: "dispatched"
    }}
  end

  defp dispatch_command(_app, command, _context) do
    {:ok, %{
      message: "Kommando /#{command.name} er ikke implementert ennå",
      command: command.name,
      executor: "unknown"
    }}
  end
end
