defmodule LlmGatewayTest do
  use ExUnit.Case, async: true

  alias LlmGateway.Request

  defmodule TestProvider do
    @behaviour LlmGateway.Provider

    @impl true
    def chat_completion(request, config) do
      send(self(), {:chat_completion, request, config})
      {:ok, %{provider: :test, request: request.messages}}
    end
  end

  setup do
    original_providers = Application.get_env(:llm_gateway, :providers)
    original_default = Application.get_env(:llm_gateway, :default_provider)
    original_credentials = Application.get_env(:llm_gateway, :system_credentials)

    providers = Map.put(original_providers || %{}, :test_provider, [
      module: __MODULE__.TestProvider,
      required_credentials: [],
      base_url: "https://unused"
    ])

    Application.put_env(:llm_gateway, :providers, providers)
    Application.put_env(:llm_gateway, :default_provider, :test_provider)
    Application.put_env(:llm_gateway, :system_credentials, %{test_provider: %{}})

    on_exit(fn ->
      Application.put_env(:llm_gateway, :providers, original_providers)
      Application.put_env(:llm_gateway, :default_provider, original_default)
      Application.put_env(:llm_gateway, :system_credentials, original_credentials)
    end)

    :ok
  end

  test "builds request and delegates to provider" do
    {:ok, response} = LlmGateway.chat_completion(:team, [%{role: "user", content: "hi"}], max_tokens: 200)

    assert_receive {:chat_completion, %Request{} = request, config}

    assert response == %{provider: :test, request: [%{role: "user", content: "hi"}]}
    assert request.max_tokens == 200
    assert Keyword.get(config, :credentials) == %{}
  end
end
