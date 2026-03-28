defmodule Noise.V1.NoiseBackend.Service do
  @moduledoc """
  gRPC service definition for Noise Backend.

  Generated manually from gateway.proto since protobuf-elixir doesn't generate service definitions.
  """

  use GRPC.Service, name: "noise.v1.NoiseBackend"

  rpc(:NotifyNewSession, Noise.V1.SessionNotification, Noise.V1.SessionAck)
  rpc(:VerifyToken, Noise.V1.VerifyTokenRequest, Noise.V1.VerifyTokenResponse)
  rpc(:ValidateDevice, Noise.V1.ValidateDeviceRequest, Noise.V1.ValidateDeviceResponse)
  rpc(:BindAccount, Noise.V1.BindAccountRequest, Noise.V1.BindAccountResponse)
  rpc(:DeleteSession, Noise.V1.DeleteSessionRequest, Noise.V1.DeleteSessionResponse)
  rpc(:Health, Noise.V1.HealthRequest, Noise.V1.HealthResponse)
end

defmodule Noise.V1.NoiseBackend.Stub do
  @moduledoc """
  gRPC client stub for Noise Backend.
  """

  use GRPC.Stub, service: Noise.V1.NoiseBackend.Service
end
