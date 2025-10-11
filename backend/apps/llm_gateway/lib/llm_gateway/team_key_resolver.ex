defmodule LlmGateway.TeamKeyResolver do
  @moduledoc """
  Behaviour for resolving team specific credentials.
  """

  @callback fetch(team_id :: term(), provider :: atom(), opts :: keyword()) :: {:ok, map()} | :error
end

defmodule LlmGateway.TeamKeyResolver.Noop do
  @moduledoc """
  Default resolver used when no team integration is configured.
  """

  @behaviour LlmGateway.TeamKeyResolver

  @impl true
  def fetch(_team_id, _provider, _opts), do: :error
end
