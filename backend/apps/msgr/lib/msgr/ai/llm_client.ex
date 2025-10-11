defmodule Messngr.AI.LlmClient do
  @moduledoc """
  Behaviour describing the minimal interface required to talk to LLM providers.
  """

  @type team_id :: term()
  @type message :: %{required(:role) => String.t(), required(:content) => String.t()}
  @type messages :: [message()]

  @callback chat_completion(team_id(), messages(), keyword()) :: {:ok, map()} | {:error, term()}
end
