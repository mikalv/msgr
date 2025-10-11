defmodule LlmGateway.HTTPClient do
  @moduledoc """
  Behaviour used by providers to execute HTTP requests.
  """

  @callback request(method :: atom(), url :: String.t(), headers :: list(), body :: iodata(), keyword()) ::
              {:ok, Finch.Response.t()} | {:error, term()}
end
