defmodule LlmGateway.Provider.OpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias LlmGateway.Provider.OpenAI
  alias LlmGateway.Request

  setup :verify_on_exit!

  setup do
    original_client = Application.get_env(:llm_gateway, :http_client)
    Application.put_env(:llm_gateway, :http_client, LlmGateway.HTTPClientMock)

    on_exit(fn -> Application.put_env(:llm_gateway, :http_client, original_client) end)

    :ok
  end

  test "posts to chat completions endpoint" do
    request = %Request{messages: [%{role: "user", content: "Hello"}], model: "gpt"}
    config = [base_url: "https://api.openai.com/v1", credentials: %{api_key: "secret"}]

    expect(LlmGateway.HTTPClientMock, :request, fn :post, url, headers, body, _opts ->
      assert url == "https://api.openai.com/v1/chat/completions"
      assert {"authorization", "Bearer secret"} in headers
      assert {"content-type", "application/json"} in headers
      assert %{"model" => "gpt"} = Jason.decode!(body)

      {:ok, %Finch.Response{status: 200, body: ~s({"id":"123"})}}
    end)

    assert {:ok, %{"id" => "123"}} = OpenAI.chat_completion(request, config)
  end

  test "returns error on non success status" do
    request = %Request{messages: [%{role: "user", content: "Hello"}], model: "gpt"}
    config = [base_url: "https://api.openai.com/v1", credentials: %{api_key: "secret"}]

    expect(LlmGateway.HTTPClientMock, :request, fn :post, _url, _headers, _body, _opts ->
      {:ok, %Finch.Response{status: 401, body: "{"}}
    end)

    assert {:error, {:http_error, 401, "{"}} = OpenAI.chat_completion(request, config)
  end
end
