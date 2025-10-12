defmodule Messngr.AI do
  @moduledoc """
  High level helpers for invoking Large Language Models from the Msgr domain.

  The module wraps `LlmGateway` with domain specific prompts so that other
  contexts (or the API) can:

    * request free-form chat completions
    * summarise longer texts for the user
    * generate suggested replies for existing conversations
    * execute ad-hoc prompts with custom system instructions
  """

  alias Messngr.AI.LlmGatewayClient
  alias Messngr.Accounts.Profile
  alias Messngr.Chat
  alias Messngr.Chat.Message

  @typedoc """
  Supported chat message structure. The gateway expects the message to contain
  the role (`system`, `user`, `assistant`, ... ) and the textual content.
  """
  @type message :: %{required(:role) => String.t(), required(:content) => String.t()}
  @type messages :: [message()]

  @forwarded_opts [:temperature, :max_tokens, :provider, :model, :response_format, :credentials, :config]

  @doc """
  Execute a raw chat completion request with the provided messages.
  """
  @spec chat(term(), messages(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat(team_id, messages, opts \\ [])

  def chat(_team_id, messages, _opts) when not is_list(messages) or messages == [] do
    {:error, :messages_required}
  end

  def chat(team_id, messages, opts) do
    with {:ok, sanitized_opts} <- sanitize_opts(opts),
         {:ok, normalized_messages} <- normalize_messages(messages),
         {:ok, response} <- do_chat(team_id, normalized_messages, sanitized_opts) do
      {:ok, response}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Summarise a long `text`.

  Options:
    * `:language` – human readable language description. Defaults to "Norwegian Bokmål".
    * `:style` – e.g. "bullet points", "short paragraph".
    * `:instructions` – additional instructions appended to the system prompt.
    * `:context` – optional extra context that is sent as a separate system message.
  """
  @spec summarize(term(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def summarize(team_id, text, opts \\ [])

  def summarize(_team_id, text, _opts) when not is_binary(text) do
    {:error, :text_required}
  end

  def summarize(team_id, text, opts) do
    if String.trim(text) == "" do
      {:error, :text_required}
    else
      system_prompt =
        opts
        |> Keyword.get(:system_prompt)
        |> case do
          nil -> default_summary_prompt(opts)
          prompt when is_binary(prompt) -> prompt
          _ -> default_summary_prompt(opts)
        end

      context_message =
        opts
        |> Keyword.get(:context)
        |> build_context_message()

      messages =
        [%{role: "system", content: system_prompt}]
        |> maybe_append(context_message)
        |> Kernel.++([%{role: "user", content: text}])

      forwarded_opts = Keyword.drop(opts, [:language, :style, :instructions, :context, :system_prompt])

      chat(team_id, messages, forwarded_opts)
    end
  end

  @doc """
  Generate a suggested reply for a conversation.

  The function fetches recent chat history and instructs the assistant to
  produce a single helpful reply.

  Options:
    * `:history_limit` – number of recent messages to include (default: 20)
    * `:system_prompt` – override the default assistant instructions
    * `:assistant_name` – what the AI should call itself (default "Msgr AI")
    * `:tone` – free text description of the desired tone (default "friendly and concise")
    * `:extra_context` – additional context injected as a system message
  """
  @spec conversation_reply(term(), binary(), Profile.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def conversation_reply(team_id, conversation_id, %Profile{} = profile, opts \\ []) do
    history_limit = Keyword.get(opts, :history_limit, 20)

    history_page = Chat.list_messages(conversation_id, limit: history_limit)
    history = history_page.entries

    system_prompt =
      opts
      |> Keyword.get(:system_prompt)
      |> case do
        nil -> default_conversation_prompt(profile, opts)
        prompt when is_binary(prompt) -> prompt
        _ -> default_conversation_prompt(profile, opts)
      end

    base_messages = [%{role: "system", content: system_prompt}]

    messages =
      base_messages
      |> maybe_append(build_context_message(opts[:extra_context]))
      |> Kernel.++(Enum.map(history, &history_entry(&1, profile)))

    forwarded_opts = Keyword.drop(opts, [:history_limit, :system_prompt, :assistant_name, :tone, :extra_context])

    chat(team_id, messages, forwarded_opts)
  end

  @doc """
  Execute an ad-hoc prompt with an optional custom system prompt.
  """
  @spec run_prompt(term(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_prompt(team_id, prompt, opts \\ [])

  def run_prompt(_team_id, prompt, _opts) when not is_binary(prompt) do
    {:error, :prompt_required}
  end

  def run_prompt(team_id, prompt, opts) do
    if String.trim(prompt) == "" do
      {:error, :prompt_required}
    else
      system_prompt =
        opts
        |> Keyword.get(:system_prompt)
        |> case do
          nil -> "You are a helpful assistant."
          prompt when is_binary(prompt) -> prompt
          _ -> "You are a helpful assistant."
        end

      messages = [%{role: "system", content: system_prompt}, %{role: "user", content: prompt}]

      forwarded_opts = Keyword.drop(opts, [:system_prompt])

      chat(team_id, messages, forwarded_opts)
    end
  end

  defp sanitize_opts(opts) do
    Enum.reduce_while(opts, {:ok, []}, fn
      {key, value}, {:ok, acc} when key in @forwarded_opts ->
        case normalize_option(key, value) do
          {:ok, nil} -> {:cont, {:ok, acc}}
          {:ok, normalized} -> {:cont, {:ok, [{key, normalized} | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _ignored, {:ok, acc} ->
        {:cont, {:ok, acc}}
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_option(:provider, value) when is_atom(value), do: {:ok, value}

  defp normalize_option(:provider, value) when is_binary(value) do
    provider =
      :llm_gateway
      |> Application.get_env(:providers, %{})
      |> Map.keys()
      |> Enum.find(fn key -> Atom.to_string(key) == value end)

    if provider do
      {:ok, provider}
    else
      {:error, {:invalid_option, :provider}}
    end
  end

  defp normalize_option(:provider, nil), do: {:ok, nil}

  defp normalize_option(:temperature, value) when is_number(value), do: {:ok, value}

  defp normalize_option(:temperature, value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      _ -> {:error, {:invalid_option, :temperature}}
    end
  end

  defp normalize_option(:temperature, nil), do: {:ok, nil}

  defp normalize_option(:max_tokens, value) when is_integer(value) and value > 0, do: {:ok, value}

  defp normalize_option(:max_tokens, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> {:ok, int}
      _ -> {:error, {:invalid_option, :max_tokens}}
    end
  end

  defp normalize_option(:max_tokens, nil), do: {:ok, nil}

  defp normalize_option(:model, value) when is_binary(value) and value != "", do: {:ok, value}
  defp normalize_option(:model, nil), do: {:ok, nil}
  defp normalize_option(:model, _), do: {:error, {:invalid_option, :model}}

  defp normalize_option(:response_format, value) when is_map(value), do: {:ok, value}
  defp normalize_option(:response_format, nil), do: {:ok, nil}
  defp normalize_option(:response_format, _), do: {:error, {:invalid_option, :response_format}}

  defp normalize_option(:credentials, value) when is_map(value) or is_list(value), do: {:ok, value}
  defp normalize_option(:credentials, nil), do: {:ok, nil}
  defp normalize_option(:credentials, _), do: {:error, {:invalid_option, :credentials}}

  defp normalize_option(:config, value) when is_map(value) or is_list(value), do: {:ok, value}
  defp normalize_option(:config, nil), do: {:ok, nil}
  defp normalize_option(:config, _), do: {:error, {:invalid_option, :config}}

  defp normalize_messages(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {message, index}, {:ok, acc} ->
      case normalize_message(message) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, %{index: index, reason: reason}}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      {:error, details} -> {:error, {:invalid_message, details}}
    end
  end

  defp normalize_message(message) when is_map(message) do
    role = Map.get(message, :role) || Map.get(message, "role")
    content = Map.get(message, :content) || Map.get(message, "content")

    cond do
      not is_binary(role) or String.trim(role) == "" -> {:error, :missing_role}
      not is_binary(content) or String.trim(content) == "" -> {:error, :missing_content}
      true -> {:ok, %{role: role, content: content}}
    end
  end

  defp normalize_message(_), do: {:error, :invalid_structure}

  defp do_chat(team_id, messages, opts) do
    case client().chat_completion(team_id, messages, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:llm_failure, reason}}
    end
  end

  defp client do
    Application.get_env(:msgr, :llm_client, LlmGatewayClient)
  end

  defp default_summary_prompt(opts) do
    language = opts |> Keyword.get(:language, "Norwegian Bokmål") |> to_string()
    style = opts |> Keyword.get(:style, "concise paragraph or bullet list when it improves clarity") |> to_string()
    instructions = opts |> Keyword.get(:instructions)

    base =
      "You summarise texts for humans. Write the summary in #{language} as a #{style}. " \
      <> "Preserve key facts, dates and names."

    case instructions do
      nil -> base
      <<>> -> base
      extra when is_binary(extra) -> base <> " " <> extra
      _ -> base
    end
  end

  defp default_conversation_prompt(%Profile{name: name}, opts) do
    assistant_name = Keyword.get(opts, :assistant_name, "Msgr AI")
    tone = Keyword.get(opts, :tone, "friendly and concise")
    display_name = name || "brukeren"

    "You are #{assistant_name}, an AI collaborator helping #{display_name} in a group chat. " \
    <> "Craft one #{tone} reply that moves the conversation forward. " \
    <> "Reference other participants by name when helpful and keep the reply short."
  end

  defp history_entry(%Message{} = message, %Profile{} = current_profile) do
    author =
      cond do
        is_nil(message.profile) -> "Participant"
        message.profile_id == current_profile.id -> message.profile.name || "You"
        true -> message.profile.name || "Participant"
      end

    body = message.body || ""
    content = "[#{author}] #{String.trim(body)}"

    %{role: "user", content: content}
  end

  defp build_context_message(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> %{role: "system", content: "Additional context:\n" <> trimmed}
    end
  end

  defp build_context_message(_), do: nil

  defp maybe_append(list, nil), do: list
  defp maybe_append(list, value), do: list ++ [value]
end
