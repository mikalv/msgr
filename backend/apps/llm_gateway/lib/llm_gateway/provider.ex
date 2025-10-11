defmodule LlmGateway.Provider do
  @moduledoc """
  Behaviour implemented by concrete LLM providers.
  """

  alias LlmGateway.Request

  @callback chat_completion(Request.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
