defmodule LlmGateway.HTTP do
  @moduledoc """
  Default HTTP client implementation backed by Finch.
  """

  @behaviour LlmGateway.HTTPClient

  @impl true
  def request(method, url, headers, body, opts \\ []) do
    method
    |> Finch.build(url, headers, body)
    |> Finch.request(LlmGateway.Finch, opts)
  end
end
