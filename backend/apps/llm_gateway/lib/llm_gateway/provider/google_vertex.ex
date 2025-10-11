defmodule LlmGateway.Provider.GoogleVertex do
  @moduledoc """
  Google Vertex AI / Gemini chat completions implementation.
  """

  @behaviour LlmGateway.Provider

  alias LlmGateway.{Request, Telemetry}

  @impl true
  def chat_completion(%Request{} = request, opts) do
    Telemetry.emit(:provider_call_started, %{provider: :google_vertex})

    with {:ok, body} <- encode_body(request, opts),
         {:ok, response} <- http_client().request(:post, chat_url(request, opts), headers(), body, http_opts(opts)),
         {:ok, parsed} <- decode_response(response) do
      Telemetry.emit(:provider_call_finished, %{provider: :google_vertex})
      {:ok, parsed}
    end
  end

  defp chat_url(request, opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    credentials = Keyword.fetch!(opts, :credentials)
    model = request.model || Keyword.fetch!(opts, :model)

    String.trim_trailing(endpoint, "/") <> "/v1beta/models/#{model}:generateContent?key=#{Map.fetch!(credentials, :api_key)}"
  end

  defp headers do
    [{"content-type", "application/json"}]
  end

  defp encode_body(%Request{} = request, opts) do
    {system_messages, conversation} = Enum.split_with(request.messages, &(&1.role == "system"))

    base = %{
      contents: Enum.map(conversation, &convert_message/1)
    }

    base =
      case system_messages do
        [first | _] -> Map.put(base, :system_instruction, %{role: "user", parts: [%{text: first.content}]})
        _ -> base
      end

    generation_config =
      %{}
      |> put_if_present(:temperature, request.temperature)
      |> put_if_present(:maxOutputTokens, request.max_tokens)

    body =
      base
      |> put_if_present(:generationConfig, map_if_present(generation_config))
      |> put_if_present(:safetySettings, Keyword.get(opts, :safety_settings))

    Jason.encode(body)
  end

  defp map_if_present(%{} = map) when map_size(map) == 0, do: nil
  defp map_if_present(map), do: map

  defp decode_response(%Finch.Response{status: status, body: body}) when status in 200..299 do
    Jason.decode(body)
  end

  defp decode_response(%Finch.Response{status: status, body: body}) do
    {:error, {:http_error, status, body}}
  end

  defp convert_message(%{role: role, content: content}) do
    %{role: map_role(role), parts: [%{text: content}]}
  end

  defp map_role("assistant"), do: "model"
  defp map_role(_), do: "user"

  defp http_client do
    Application.get_env(:llm_gateway, :http_client, LlmGateway.HTTP)
  end

  defp http_opts(opts) do
    Keyword.get(opts, :http_opts, [])
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
