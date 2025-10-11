defmodule MainProxy.Plug.Default do
  @moduledoc false
  @behaviour Plug

  require Logger

  @impl true
  def init(options) do
    options
  end

  @impl true
  def call(conn, opts) do
    Logger.debug("MainProxy.Default call opts: #{inspect(opts)}")
    phoenix_endpoint = case Application.get_env(:edge_router, :default_endpoint, nil) do
      nil ->
        MainProxy.Plug.NotFound
      value ->
        value
    end

    conn
    |> phoenix_endpoint.call([])
  end
end
