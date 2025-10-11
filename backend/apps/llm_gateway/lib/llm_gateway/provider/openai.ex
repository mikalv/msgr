defmodule LlmGateway.Provider.OpenAI do
  @moduledoc """
  Implementation for OpenAI compatible chat completion endpoints.
  """

  @behaviour LlmGateway.Provider

  alias LlmGateway.{Request, Telemetry}

  @impl true
  def chat_completion(%Request{} = request, opts) do
    Telemetry.emit(:provider_call_started, %{provider: :openai})

    with {:ok, body} <- encode_body(request),
         {:ok, response} <- http_client().request(:post, chat_url(opts), headers(opts), body, http_opts(opts)),
         {:ok, parsed} <- decode_response(response) do
      Telemetry.emit(:provider_call_finished, %{provider: :openai})
      {:ok, parsed}
    end
  end

  defp chat_url(opts) do
    base_url = Keyword.fetch!(opts, :base_url)
    String.trim_trailing(base_url, "/") <> "/chat/completions"
  end

  defp headers(opts) do
    credentials = Keyword.fetch!(opts, :credentials)

    [
      {"authorization", "Bearer #{Map.fetch!(credentials, :api_key)}"},
      {"content-type", "application/json"}
    ] ++ organization_header(credentials)
  end

  defp organization_header(%{organization: org}) when is_binary(org),
    do: [{"openai-organization", org}]

  defp organization_header(_), do: []

  defp encode_body(%Request{} = request) do
    body =
      %{model: request.model, messages: request.messages}
      |> put_if_present(:max_tokens, request.max_tokens)
      |> put_if_present(:temperature, request.temperature)
      |> put_if_present(:response_format, request.response_format)

    Jason.encode(body)
  end

  defp decode_response(%Finch.Response{status: status, body: body}) when status in 200..299 do
    Jason.decode(body)
  end

  defp decode_response(%Finch.Response{status: status, body: body}) do
    {:error, {:http_error, status, body}}
  end

  defp http_client do
    Application.get_env(:llm_gateway, :http_client, LlmGateway.HTTP)
  end

  defp http_opts(opts) do
    Keyword.get(opts, :http_opts, [])
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
