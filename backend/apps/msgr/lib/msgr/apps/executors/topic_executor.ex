defmodule Messngr.Apps.Executors.TopicExecutor do
  @moduledoc """
  Built-in executor for /topic commands.

  Usage: /topic New channel topic here
  Returns an :update_topic action that the controller applies.
  """

  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{args: args} = _command, _context) do
    case validate_args(args) do
      {:ok, topic} ->
        {:ok, %{type: :update_topic, topic: topic, content: "📝 Topic oppdatert: #{topic}"}}

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
