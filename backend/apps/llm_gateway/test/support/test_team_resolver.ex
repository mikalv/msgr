defmodule LlmGateway.TestTeamResolver do
  @moduledoc false

  @behaviour LlmGateway.TeamKeyResolver

  @impl true
  def fetch(team_id, provider, opts) do
    assignments = Keyword.get(opts, :assignments, %{})

    case Map.get(assignments, {team_id, provider}) || Map.get(assignments, provider) do
      nil -> :error
      value -> {:ok, value}
    end
  end
end
