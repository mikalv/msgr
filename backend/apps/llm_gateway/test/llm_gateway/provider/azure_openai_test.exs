defmodule LlmGateway.Provider.AzureOpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias LlmGateway.Provider.AzureOpenAI
  alias LlmGateway.Request

  setup :verify_on_exit!

  setup do
    original_client = Application.get_env(:llm_gateway, :http_client)
    Application.put_env(:llm_gateway, :http_client, LlmGateway.HTTPClientMock)

    on_exit(fn -> Application.put_env(:llm_gateway, :http_client, original_client) end)

    :ok
  end

  test "posts to azure deployment endpoint" do
    request = %Request{messages: [%{role: "user", content: "Hi"}], model: "gpt"}

    config = [
      endpoint: "https://resource.openai.azure.com",
      deployment: "my-model",
      api_version: "2024-05-01-preview",
      credentials: %{api_key: "azure-key"}
    ]

    expect(LlmGateway.HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
      assert url == "https://resource.openai.azure.com/openai/deployments/my-model/chat/completions?api-version=2024-05-01-preview"
      assert {"api-key", "azure-key"} in headers
      payload = Jason.decode!(body)
      assert payload["messages"] == [%{"role" => "user", "content" => "Hi"}]

      {:ok, %Finch.Response{status: 200, body: ~s({"ok":true})}}
    end)

    assert {:ok, %{"ok" => true}} = AzureOpenAI.chat_completion(request, config)
  end
end
