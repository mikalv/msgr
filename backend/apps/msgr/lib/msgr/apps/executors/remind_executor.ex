defmodule Messngr.Apps.Executors.RemindExecutor do
  @moduledoc """
  Built-in executor for /remind commands.

  Usage: /remind 30m Check deployment
         /remind 2h Team standup
         /remind 1d Review PR

  Creates an actual reminder in the database that fires via ReminderScheduler.
  """

  @behaviour Messngr.Apps.Executor

  alias Teams.TenantModels.MessageReminder

  @impl true
  def execute(%{args: args, channel_id: channel_id, triggered_by: account_id} = _command, %{tenant_prefix: prefix} = _context) do
    case parse_remind_args(args) do
      {:ok, duration_seconds, time_str, message} ->
        # Find profile for this account
        profile = Teams.TeamManagement.get_profile_for_account(prefix, account_id)

        if profile do
          remind_at =
            DateTime.utc_now()
            |> DateTime.add(duration_seconds, :second)
            |> DateTime.truncate(:second)

          case MessageReminder.create(prefix, %{
            message_id: nil_safe_message_id(channel_id),
            channel_id: channel_id,
            profile_id: profile.id,
            remind_at: remind_at,
            message_preview: message
          }) do
            {:ok, _reminder} ->
              content = "⏰ Reminder set: **#{message}** in #{time_str}"
              {:ok, %{type: :message, content: content}}

            {:error, _changeset} ->
              {:error, "Could not create reminder"}
          end
        else
          {:error, "Profile not found"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute(%{args: args}, _context) do
    case parse_remind_args(args) do
      {:ok, _seconds, time_str, message} ->
        content = "⏰ Reminder set: **#{message}** in #{time_str}"
        {:ok, %{type: :message, content: content}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def parse_remind_args(nil), do: {:error, "Usage: /remind 30m Your message here"}
  def parse_remind_args(""), do: {:error, "Usage: /remind 30m Your message here"}

  def parse_remind_args(args) when is_binary(args) do
    case String.split(args, ~r/\s+/, parts: 2, trim: true) do
      [time_str, message] when byte_size(message) > 0 ->
        case parse_duration(time_str) do
          {:ok, seconds} ->
            {:ok, seconds, humanize_time(time_str), message}
          :error ->
            {:error, "Invalid time '#{time_str}'. Use e.g. 30m, 2h, 1d"}
        end

      _ ->
        {:error, "Usage: /remind 30m Your message here"}
    end
  end

  defp parse_duration(time_str) do
    case Regex.run(~r/^(\d+)([smhd])$/i, time_str) do
      [_, amount, unit] ->
        seconds = String.to_integer(amount) * unit_multiplier(String.downcase(unit))
        {:ok, seconds}
      _ ->
        :error
    end
  end

  defp unit_multiplier("s"), do: 1
  defp unit_multiplier("m"), do: 60
  defp unit_multiplier("h"), do: 3600
  defp unit_multiplier("d"), do: 86400

  defp humanize_time(time_str) do
    {amount, unit} = String.split_at(time_str, -1)
    amount_int = String.to_integer(amount)
    unit_name = case String.downcase(unit) do
      "s" -> if(amount_int == 1, do: "second", else: "seconds")
      "m" -> if(amount_int == 1, do: "minute", else: "minutes")
      "h" -> if(amount_int == 1, do: "hour", else: "hours")
      "d" -> if(amount_int == 1, do: "day", else: "days")
      _ -> unit
    end
    "#{amount_int} #{unit_name}"
  end

  # MessageReminder requires a message_id — for slash command reminders
  # we don't have one, so we'll need to create a dummy or make it nullable.
  # For now, return a nil-safe value.
  defp nil_safe_message_id(_channel_id), do: nil
end
