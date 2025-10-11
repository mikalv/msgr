defmodule LlmGateway.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: LlmGateway.Finch, pools: pools()},
      LlmGateway.Telemetry
    ]

    opts = [strategy: :one_for_one, name: LlmGateway.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pools do
    Application.get_env(:llm_gateway, :finch_pools, [])
  end
end
