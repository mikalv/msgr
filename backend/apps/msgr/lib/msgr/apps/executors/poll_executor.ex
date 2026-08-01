defmodule Messngr.Apps.Executors.PollExecutor do
  @moduledoc """
  Built-in executor for /poll commands.

  Usage: /poll "What for lunch?" "Pizza" "Sushi" "Tacos"
  Creates a system message with numbered poll options.
  """

  @behaviour Messngr.Apps.Executor

  @emoji_numbers ~w(1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟)

  @impl true
  def execute(%{args: args} = _command, _context) do
    case parse_poll_args(args) do
      {:ok, question, options} ->
        content = format_poll(question, options)
        {:ok, %{type: :message, content: content}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def parse_poll_args(nil),
    do: {:error, "Bruk: /poll \"Spørsmål\" \"Alternativ 1\" \"Alternativ 2\""}

  def parse_poll_args(""),
    do: {:error, "Bruk: /poll \"Spørsmål\" \"Alternativ 1\" \"Alternativ 2\""}

  def parse_poll_args(args) when is_binary(args) do
    case extract_quoted_parts(args) do
      {:quoted, [question | options]} when length(options) >= 2 ->
        {:ok, question, options}

      {:quoted, _parts} ->
        {:error,
         "En poll trenger minst 2 alternativer. Bruk: /poll \"Spørsmål\" \"Alt 1\" \"Alt 2\""}

      {:words, [question | options]} when length(options) >= 2 ->
        {:ok, question, options}

      {:words, _parts} ->
        {:error,
         "En poll trenger minst 2 alternativer. Bruk: /poll \"Spørsmål\" \"Alt 1\" \"Alt 2\""}
    end
  end

  defp extract_quoted_parts(text) do
    regex = ~r/"([^"]+)"/

    case Regex.scan(regex, text) do
      [] ->
        {:words, String.split(text, ~r/\s+/, trim: true)}

      matches ->
        {:quoted, Enum.map(matches, fn [_full, captured] -> captured end)}
    end
  end

  defp format_poll(question, options) do
    header = "📊 **#{question}**\n"

    body =
      options
      |> Enum.with_index()
      |> Enum.map(fn {option, idx} ->
        emoji = Enum.at(@emoji_numbers, idx, "#{idx + 1}.")
        "#{emoji}  #{option}"
      end)
      |> Enum.join("\n")

    footer = "\n\n_Reager med emoji for å stemme!_"

    header <> "\n" <> body <> footer
  end
end
