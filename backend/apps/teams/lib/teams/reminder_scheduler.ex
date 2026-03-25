defmodule Teams.ReminderScheduler do
  @moduledoc """
  Periodically checks for due message reminders and delivers them
  as push notifications + WebSocket events.
  """

  use GenServer
  require Logger

  alias Teams.TenantModels.MessageReminder
  alias Teams.Tenancy

  @check_interval :timer.seconds(30)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_reminders, state) do
    check_all_tenants()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_reminders, @check_interval)
  end

  defp check_all_tenants do
    # Get all tenant prefixes
    teams = Teams.Repo.all(Teams.Schemas.Team)

    for team <- teams do
      prefix = team.schema_name
      try do
        due = MessageReminder.find_due(prefix)

        for reminder <- due do
          deliver_reminder(team, prefix, reminder)
          MessageReminder.mark_delivered(prefix, reminder.id)
        end
      rescue
        e -> Logger.debug("Reminder check failed for #{prefix}: #{inspect(e)}")
      end
    end
  end

  defp deliver_reminder(team, prefix, reminder) do
    profile = reminder.profile
    message = reminder.message

    if profile do
      # Extract message text for notification
      content = if message do
        case message.content do
          %{"text" => text} when is_binary(text) -> text
          text when is_binary(text) -> text
          _ -> reminder.message_preview || "Reminder"
        end
      else
        reminder.message_preview || "Reminder"
      end

      preview = String.slice(content, 0, 100)

      # Post reminder to user's self-DM channel (notes to self)
      try do
        case Teams.Channels.create_dm(prefix, [profile.id]) do
          {:ok, self_channel} ->
            Teams.Messages.create_message(prefix, %{
              channel_id: self_channel.id,
              sender_profile_id: profile.id,
              content: %{"text" => "⏰ **Reminder:** #{preview}", "system" => true}
            })
          _ -> :ok
        end
      rescue
        _ -> :ok
      end

      Logger.info("[Reminder] Delivering to #{profile.display_name}: #{preview}")

      # Send via WebSocket to the user's connected clients
      MessngrWeb.Endpoint.broadcast(
        "team:#{team.slug}",
        "reminder:fired",
        %{
          reminder_id: reminder.id,
          message_id: reminder.message_id,
          channel_id: reminder.channel_id,
          profile_id: reminder.profile_id,
          message_preview: preview,
          remind_at: reminder.remind_at
        }
      )

      # Also dispatch push notification
      if profile.account_id do
        tokens = get_push_tokens(profile.account_id)
        apns_payload = Messngr.Push.APNS.message_payload(
          "Reminder",
          preview,
          channel_id: reminder.channel_id,
          message_id: reminder.message_id,
          team_slug: team.slug
        )

        for {token, platform} <- tokens do
          case platform do
            "apns" -> Messngr.Push.APNS.push(token, apns_payload)
            "web_push" ->
              web_payload = %{
                title: "Reminder",
                body: preview,
                icon: "/icons/Icon-192.png",
                tag: "reminder-#{reminder.id}",
                data: %{
                  channel_id: reminder.channel_id,
                  message_id: reminder.message_id,
                  team_slug: team.slug,
                  type: "reminder"
                }
              }
              Messngr.Push.WebPush.push(token, web_payload)
            _ -> :ok
          end
        end
      end
    end
  end

  defp get_push_tokens(account_id) do
    import Ecto.Query

    from(t in Messngr.Push.DeviceToken,
      where: t.account_id == ^account_id and t.enabled == true,
      select: {t.token, t.platform}
    )
    |> Messngr.Repo.all()
  end
end
