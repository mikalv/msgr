defmodule Messngr.RustGateway.Endpoint do
  @moduledoc """
  gRPC endpoint for Rust Gateway to call Elixir backend.

  This server listens on port 50052 (configurable) and handles requests
  from Rust Gateway for device validation.
  """

  use GRPC.Endpoint

  run(Messngr.RustGateway.Server)
end
