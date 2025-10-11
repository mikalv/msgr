defmodule LlmGateway.Provider.GoogleVertexTest do
  use ExUnit.Case, async: true

  import Mox

  alias LlmGateway.Provider.GoogleVertex
  alias LlmGateway.Request

  setup :verify_on_exit!

  setup do
    original_client = Application.get_env(:llm_gateway, :http_client)
    Application.put_env(:llm_gateway, :http_client, LlmGateway.HTTPClientMock)

    on_exit(fn -> Application.put_env(:llm_gateway, :http_client, original_client) end)

    :ok
  end

  test "transforms messages into gemini payload" do
    request = %Request{
      messages: [
        %{role: "system", content: "You are helpful"},
        %{role: "user", content: "Hi"},
        %{role: "assistant", content: "Hello"}
      ],
      model: "gemini-pro",
      temperature: 0.1,
      max_tokens: 256
    }

    config = [endpoint: "https://generativelanguage.googleapis.com", credentials: %{api_key: "key"}]

    expect(LlmGateway.HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
      assert url == "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=key"
      assert {"content-type", "application/json"} in headers

      payload = Jason.decode!(body)
      assert payload["system_instruction"]["parts"] == [%{"text" => "You are helpful"}]
      assert [%{"role" => "user"}, %{"role" => "model"}] = payload["contents"]
      assert payload["generationConfig"]["temperature"] == 0.1
      assert payload["generationConfig"]["maxOutputTokens"] == 256

      {:ok, %Finch.Response{status: 200, body: ~s({"output":"ok"})}}
    end)

    assert {:ok, %{"output" => "ok"}} = GoogleVertex.chat_completion(request, config)
  end
end
