defmodule Messngr.AI.LlmGatewayClient do
  @moduledoc """
  Default implementation of `Messngr.AI.LlmClient` which delegates to `LlmGateway`.
  """

  @behaviour Messngr.AI.LlmClient

  @impl true
  def chat_completion(team_id, messages, opts \\ []) do
    LlmGateway.chat_completion(team_id, messages, opts)
  end
end
