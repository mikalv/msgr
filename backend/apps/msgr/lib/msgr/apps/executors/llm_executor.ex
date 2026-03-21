defmodule Messngr.Apps.Executors.LlmExecutor do
  @moduledoc """
  LLM executor for no-code AI-powered slash commands.

  Reads system_prompt and tools from the app manifest, calls the LLM proxy
  using the OpenAI-compatible chat completions API, handles tool calling,
  and returns the final response as a system message.
  """

  @behaviour Messngr.Apps.Executor

  require Logger

  alias Messngr.Apps.Tools.Registry

  @llm_proxy_url "https://llmproxy.rprxy.mdma.sh/v1/chat/completions"
  @default_model "qwen3.5-abliterated-35b"
  @max_tool_rounds 5

  @impl true
  def execute(%{args: args} = command, %{app: app} = context) do
    manifest = app.manifest || %{}
    executor_config = manifest["executor"] || %{}

    system_prompt = executor_config["system_prompt"] || default_system_prompt()
    model = executor_config["model"] || @default_model
    tool_names = executor_config["tools"] || []
    max_tokens = executor_config["max_tokens"] || 2048
    temperature = executor_config["temperature"] || 0.3

    # Resolve tool definitions
    tools = resolve_tools(tool_names)
    tool_defs = Enum.map(tools, &tool_to_openai_schema/1)

    # Build initial messages
    messages = [
      %{"role" => "system", "content" => system_prompt},
      %{"role" => "user", "content" => args || ""}
    ]

    # Build tool context (secrets + channel config)
    tool_context = build_tool_context(context)

    case run_llm_loop(model, messages, tool_defs, tools, tool_context, temperature, max_tokens, 0) do
      {:ok, response_text} ->
        {:ok, %{type: :message, content: response_text}}

      {:error, reason} ->
        Logger.error("LLM executor failed for /#{command.command}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Run the LLM loop, handling tool calls up to @max_tool_rounds
  defp run_llm_loop(_model, _messages, _tool_defs, _tools, _ctx, _temp, _max_tok, round)
       when round >= @max_tool_rounds do
    {:error, "LLM brukte for mange verktøy-runder (maks #{@max_tool_rounds})"}
  end

  defp run_llm_loop(model, messages, tool_defs, tools, tool_context, temperature, max_tokens, round) do
    body = build_request_body(model, messages, tool_defs, temperature, max_tokens)

    case http_post(@llm_proxy_url, body) do
      {:ok, %{"choices" => [%{"message" => message} | _]}} ->
        handle_llm_response(message, model, messages, tool_defs, tools, tool_context, temperature, max_tokens, round)

      {:ok, unexpected} ->
        Logger.warning("Unexpected LLM response: #{inspect(unexpected)}")
        {:error, "Uventet svar fra LLM"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_llm_response(%{"tool_calls" => tool_calls} = assistant_msg, model, messages, tool_defs, tools, tool_context, temperature, max_tokens, round)
       when is_list(tool_calls) and tool_calls != [] do
    # Execute each tool call and collect results
    tool_results =
      Enum.map(tool_calls, fn tool_call ->
        execute_tool_call(tool_call, tools, tool_context)
      end)

    # Append assistant message + tool results to conversation
    updated_messages =
      messages ++
        [assistant_msg] ++
        Enum.map(tool_results, fn {tool_call_id, result} ->
          %{
            "role" => "tool",
            "tool_call_id" => tool_call_id,
            "content" => Jason.encode!(result)
          }
        end)

    # Continue the loop
    run_llm_loop(model, updated_messages, tool_defs, tools, tool_context, temperature, max_tokens, round + 1)
  end

  defp handle_llm_response(%{"content" => content}, _model, _messages, _tool_defs, _tools, _tool_context, _temperature, _max_tokens, _round)
       when is_binary(content) do
    {:ok, content}
  end

  defp handle_llm_response(msg, _model, _messages, _tool_defs, _tools, _tool_context, _temperature, _max_tokens, _round) do
    Logger.warning("LLM response missing content: #{inspect(msg)}")
    {:ok, msg["content"] || "Ingen respons fra LLM"}
  end

  defp execute_tool_call(
         %{"id" => tool_call_id, "function" => %{"name" => name, "arguments" => arguments_json}},
         tools,
         tool_context
       ) do
    args =
      case Jason.decode(arguments_json) do
        {:ok, parsed} -> parsed
        {:error, _} -> %{}
      end

    tool_module = Enum.find(tools, fn mod -> mod.name() == name end)

    result =
      if tool_module do
        case tool_module.execute(args, tool_context) do
          {:ok, data} -> data
          {:error, reason} -> %{"error" => to_string(reason)}
        end
      else
        %{"error" => "Unknown tool: #{name}"}
      end

    {tool_call_id, result}
  end

  defp resolve_tools(tool_names) do
    tool_names
    |> Enum.map(&Registry.get_tool/1)
    |> Enum.reject(&is_nil/1)
  end

  defp tool_to_openai_schema(tool_module) do
    %{
      "type" => "function",
      "function" => %{
        "name" => tool_module.name(),
        "description" => tool_module.description(),
        "parameters" => tool_module.parameters()
      }
    }
  end

  defp build_request_body(model, messages, tool_defs, temperature, max_tokens) do
    body = %{
      "model" => model,
      "messages" => messages,
      "temperature" => temperature,
      "max_tokens" => max_tokens
    }

    if tool_defs != [] do
      Map.put(body, "tools", tool_defs)
    else
      body
    end
  end

  defp build_tool_context(%{installation: installation} = _context) when not is_nil(installation) do
    %{
      config: installation.config || %{},
      secrets: decrypt_secrets(installation.secrets_encrypted)
    }
  end

  defp build_tool_context(_context) do
    %{config: %{}, secrets: %{}}
  end

  defp decrypt_secrets(nil), do: %{}

  defp decrypt_secrets(encrypted) when is_binary(encrypted) do
    # TODO: implement proper decryption when secret management is ready
    case Jason.decode(encrypted) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp http_post(url, body) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case :httpc.request(
           :post,
           {String.to_charlist(url), Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end),
            ~c"application/json", Jason.encode!(body)},
           [{:timeout, 60_000}, {:connect_timeout, 10_000}],
           [{:body_format, :binary}]
         ) do
      {:ok, {{_, status, _}, _headers, response_body}} when status >= 200 and status < 300 ->
        Jason.decode(response_body)

      {:ok, {{_, status, _}, _headers, response_body}} ->
        Logger.error("LLM proxy returned #{status}: #{response_body}")
        {:error, "LLM proxy feil: #{status}"}

      {:error, reason} ->
        Logger.error("HTTP request to LLM proxy failed: #{inspect(reason)}")
        {:error, "Kunne ikke nå LLM proxy"}
    end
  end

  defp default_system_prompt do
    "Du er en hjelpsom assistent i en team-chat. Svar kortfattet og nyttig."
  end
end
