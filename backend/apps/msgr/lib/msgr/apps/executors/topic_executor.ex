defmodule Messngr.Apps.Executors.TopicExecutor do
  @moduledoc """
  Built-in executor for /topic commands.

  Usage: /topic New channel topic here
  Updates the channel's topic.
  """

  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{args: args, channel_id: channel_id} = _command, %{tenant_prefix: prefix} = _context) do
    case validate_args(args) do
      {:ok, topic} ->
        case Teams.Channels.update_topic(prefix, channel_id, topic) do
          {:ok, _channel} ->
            {:ok, %{type: :message, content: "📝 Topic oppdatert: #{topic}"}}

          {:error, reason} ->
            {:error, "Kunne ikke oppdatere topic: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_args(nil), do: {:error, "Bruk: /topic Ny topic tekst her"}
  defp validate_args(""), do: {:error, "Bruk: /topic Ny topic tekst her"}

  defp validate_args(args) when is_binary(args) do
    topic = String.trim(args)
    if byte_size(topic) > 0 do
      {:ok, topic}
    else
      {:error, "Bruk: /topic Ny topic tekst her"}
    end
  end
end
