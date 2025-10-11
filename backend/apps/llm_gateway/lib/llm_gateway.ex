defmodule LlmGateway do
  @moduledoc """
  Entry point for LLM interactions across the umbrella.

  The gateway exposes a unified API so other services can request
  completions without being coupled to a specific vendor. Provider
  selection and credential resolution happens automatically by
  combining team specific settings with the system level defaults.
  """

  alias LlmGateway.{Config, Request}

  @type provider :: Config.provider()
  @type team_id :: term()

  @doc """
  Executes a chat completion request.

  The call will resolve credentials in the following order:

    * team specific configuration resolved via `Config.team_resolver/0`
    * system wide configuration defined through `:llm_gateway` config

  `opts` can be used to force a provider (`:provider`) or pass provider
  specific overrides such as `:api_key`.
  """
  @spec chat_completion(team_id(), Request.chat_messages(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat_completion(team_id, messages, opts \\ []) do
    request_opts = Keyword.take(opts, [:temperature, :max_tokens, :model, :response_format])
    config_overrides = Keyword.take(opts, [:credentials, :config])
    provider = resolve_provider(opts)

    with {:ok, request} <- Request.build(messages, request_opts),
         {:ok, config} <- Config.resolve(team_id, provider, config_overrides),
         {:ok, provider_module} <- Config.provider_module(provider) do
      provider_module.chat_completion(request, config)
    end
  end

  defp resolve_provider(opts) do
    opts[:provider] || Application.get_env(:llm_gateway, :default_provider, :openai)
  end
end
