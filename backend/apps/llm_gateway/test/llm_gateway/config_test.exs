defmodule LlmGateway.ConfigTest do
  use ExUnit.Case, async: false

  alias LlmGateway.Config

  setup do
    original_providers = Application.get_env(:llm_gateway, :providers)
    original_credentials = Application.get_env(:llm_gateway, :system_credentials)
    original_resolver = Application.get_env(:llm_gateway, :team_resolver)

    on_exit(fn ->
      Application.put_env(:llm_gateway, :providers, original_providers)
      Application.put_env(:llm_gateway, :system_credentials, original_credentials)
      Application.put_env(:llm_gateway, :team_resolver, original_resolver)
    end)

    :ok
  end

  test "merges credentials from system, team and overrides" do
    providers = %{
      openai: [
        module: LlmGateway.Provider.OpenAI,
        base_url: "https://example",
        required_credentials: [:api_key]
      ]
    }

    Application.put_env(:llm_gateway, :providers, providers)
    Application.put_env(:llm_gateway, :system_credentials, %{openai: %{api_key: "system", organization: "org"}})
    Application.put_env(:llm_gateway, :team_resolver, {LlmGateway.TestTeamResolver, assignments: %{{123, :openai} => %{api_key: "team"}}})

    {:ok, config} = Config.resolve(123, :openai, credentials: [api_key: "override"])

    assert Keyword.get(config, :base_url) == "https://example"
    assert Keyword.get(config, :credentials) == %{api_key: "override", organization: "org"}
  end

  test "returns error when required credential missing" do
    providers = %{
      openai: [
        module: LlmGateway.Provider.OpenAI,
        base_url: "https://example",
        required_credentials: [:api_key]
      ]
    }

    Application.put_env(:llm_gateway, :providers, providers)
    Application.put_env(:llm_gateway, :system_credentials, %{})
    Application.put_env(:llm_gateway, :team_resolver, {LlmGateway.TestTeamResolver, assignments: %{}})

    assert {:error, {:missing_credential, :openai, :api_key}} = Config.resolve(321, :openai, [])
  end
end
