defmodule Messngr.Apps.Executors.RemindExecutor do
  @moduledoc """
  Built-in executor for /remind commands.

  Usage: /remind 30m Check deployment
         /remind 2h Team standup

  For now: acknowledges and posts a message. Actual timer scheduling is future work.
  """

  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{args: args} = _command, _context) do
    case parse_remind_args(args) do
      {:ok, time_str, message} ->
        content = "⏰ Påminnelse satt: **#{message}** om #{time_str}"
        {:ok, %{type: :message, content: content}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def parse_remind_args(nil), do: {:error, "Bruk: /remind 30m Beskjed her"}
  def parse_remind_args(""), do: {:error, "Bruk: /remind 30m Beskjed her"}

  def parse_remind_args(args) when is_binary(args) do
    case String.split(args, ~r/\s+/, parts: 2, trim: true) do
      [time_str, message] when byte_size(message) > 0 ->
        if valid_time?(time_str) do
          {:ok, humanize_time(time_str), message}
        else
          {:error, "Ugyldig tid '#{time_str}'. Bruk f.eks. 30m, 2h, 1d"}
        end

      _ ->
        {:error, "Bruk: /remind 30m Beskjed her"}
    end
  end

  defp valid_time?(time_str) do
    String.match?(time_str, ~r/^\d+[smhd]$/i)
  end

  defp humanize_time(time_str) do
    {amount, unit} = String.split_at(time_str, -1)
    amount_int = String.to_integer(amount)

    unit_name =
      case String.downcase(unit) do
        "s" -> if(amount_int == 1, do: "sekund", else: "sekunder")
        "m" -> if(amount_int == 1, do: "minutt", else: "minutter")
        "h" -> if(amount_int == 1, do: "time", else: "timer")
        "d" -> if(amount_int == 1, do: "dag", else: "dager")
        _ -> unit
      end

    "#{amount_int} #{unit_name}"
  end
end
