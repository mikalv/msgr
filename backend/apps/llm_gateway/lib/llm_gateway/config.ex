defmodule LlmGateway.Config do
  @moduledoc """
  Handles runtime configuration for providers and credentials.
  """

  @typedoc """
  Registered provider identifiers.
  """
  @type provider :: atom()

  @type credential_source :: {:system, map()} | {:team, map()} | {:override, map()}

  @spec resolve(term(), provider(), keyword()) :: {:ok, map()} | {:error, term()}
  def resolve(team_id, provider, overrides) do
    with {:ok, base} <- provider_base(provider),
         {:ok, merged} <- merge_credentials(base, team_id, provider, overrides) do
      {:ok, merged}
    end
  end

  @doc """
  Returns the configured module for a provider.
  """
  @spec provider_module(provider()) :: {:ok, module()} | {:error, :unknown_provider}
  def provider_module(provider) do
    providers()
    |> Map.get(provider)
    |> case do
      nil -> {:error, :unknown_provider}
      config -> {:ok, Keyword.fetch!(config, :module)}
    end
  end

  @doc """
  Returns a keyword list with the provider configuration.
  """
  @spec provider_base(provider()) :: {:ok, keyword()} | {:error, :unknown_provider}
  def provider_base(provider) do
    providers()
    |> Map.get(provider)
    |> case do
      nil -> {:error, :unknown_provider}
      config -> {:ok, Keyword.delete(config, :module)}
    end
  end

  defp merge_credentials(base, team_id, provider, overrides) do
    override_credentials = overrides |> Keyword.get(:credentials) |> normalise_map()
    override_config = overrides |> Keyword.get(:config) |> normalise_keyword()
    system = system_credentials(provider)
    team = team_credentials(team_id, provider)

    {:ok,
     base
     |> Keyword.merge(override_config)
     |> Keyword.put(:credentials, merge_maps([system, team, override_credentials]))
     |> ensure_required_credentials(provider)}
  end

  defp merge_maps(maps) do
    Enum.reduce(maps, %{}, fn
      map, acc when is_map(map) -> Map.merge(acc, map, fn _k, _v1, v2 -> v2 end)
      _, acc -> acc
    end)
  end

  defp normalise_map(nil), do: %{}
  defp normalise_map(map) when is_map(map), do: map
  defp normalise_map(keyword) when is_list(keyword), do: Map.new(keyword)
  defp normalise_map(_), do: %{}

  defp normalise_keyword(nil), do: []
  defp normalise_keyword(map) when is_map(map), do: Map.to_list(map)
  defp normalise_keyword(list) when is_list(list), do: list
  defp normalise_keyword(_), do: []

  defp ensure_required_credentials(config, provider) do
    required = required_credentials(provider)
    credentials = Keyword.get(config, :credentials, %{})

    case Enum.find(required, &missing_credential?(credentials, &1)) do
      nil -> {:ok, config}
      missing -> {:error, {:missing_credential, provider, missing}}
    end
  end

  defp missing_credential?(credentials, key) do
    is_nil(Map.get(credentials, key))
  end

  defp required_credentials(provider) do
    providers()
    |> Map.get(provider, [])
    |> Keyword.get(:required_credentials, [])
  end

  defp system_credentials(provider) do
    Application.get_env(:llm_gateway, :system_credentials, %{})
    |> Map.get(provider)
  end

  defp team_credentials(team_id, provider) do
    {module, opts} = team_resolver()

    case module.fetch(team_id, provider, opts) do
      {:ok, creds} -> creds
      _ -> nil
    end
  end

  defp team_resolver do
    Application.get_env(:llm_gateway, :team_resolver, {LlmGateway.TeamKeyResolver.Noop, []})
  end

  defp providers do
    Application.get_env(:llm_gateway, :providers, %{})
  end
end
