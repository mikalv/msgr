defmodule MessngrWeb.ReminderController do
  use MessngrWeb, :controller

  alias Teams.TenantModels.MessageReminder
  alias Teams.{Messages, TeamManagement}

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/reminders — create a reminder"
  def create(conn, %{"message_id" => message_id, "remind_at" => remind_at_str} = params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account
    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      case DateTime.from_iso8601(remind_at_str) do
        {:ok, remind_at, _} ->
          # Get message for preview
          message = Messages.get_message(prefix, message_id)

          preview =
            if message do
              case message.content do
                %{"text" => t} -> String.slice(t, 0, 200)
                t when is_binary(t) -> String.slice(t, 0, 200)
                _ -> nil
              end
            end

          attrs = %{
            message_id: message_id,
            channel_id: params["channel_id"] || (message && message.channel_id),
            profile_id: profile.id,
            remind_at: DateTime.truncate(remind_at, :second),
            message_preview: preview
          }

          case MessageReminder.create(prefix, attrs) do
            {:ok, reminder} ->
              conn
              |> put_status(:created)
              |> json(%{
                data: %{
                  id: reminder.id,
                  message_id: reminder.message_id,
                  remind_at: reminder.remind_at,
                  message_preview: reminder.message_preview
                }
              })

            {:error, changeset} ->
              {:error, changeset}
          end

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid remind_at datetime. Use ISO 8601 format."})
      end
    end
  end

  @doc "GET /api/teams/:slug/reminders — list my pending reminders"
  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account
    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      json(conn, %{data: []})
    else
      reminders = MessageReminder.list_for_profile(prefix, profile.id)

      json(conn, %{
        data:
          Enum.map(reminders, fn r ->
            %{
              id: r.id,
              message_id: r.message_id,
              channel_id: r.channel_id,
              remind_at: r.remind_at,
              message_preview: r.message_preview
            }
          end)
      })
    end
  end
end
