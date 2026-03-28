defmodule Messngr.RustGateway.Client do
  @moduledoc """
  gRPC client for communicating with Rust Gateway.

  Handles binding accounts to Noise sessions after OTP verification.
  """

  alias Noise.V1.{BindAccountRequest, BindAccountResponse}
  alias Noise.V1.NoiseBackend.Stub

  require Logger

  @doc """
  Bind an account to a Noise session in Rust Gateway.

  Called after OTP verification to tell Rust Gateway which account/profile
  owns a particular session.
  """
  @spec bind_account(map()) :: :ok | {:error, term()}
  def bind_account(
        %{
          session_id: session_id,
          session_token: session_token,
          account_id: account_id
        } = params
      ) do
    request = %BindAccountRequest{
      session_id: session_id,
      session_token: session_token,
      account_id: account_id,
      profile_id: Map.get(params, :profile_id),
      device_id: Map.get(params, :device_id)
    }

    case get_channel() do
      {:ok, channel} ->
        case Stub.bind_account(channel, request) do
          {:ok, %BindAccountResponse{success: true}} ->
            Logger.info("Successfully bound account to Noise session",
              session_id: session_id,
              account_id: account_id
            )

            :ok

          {:ok, %BindAccountResponse{success: false, error: error}} ->
            Logger.error("Failed to bind account to Noise session",
              session_id: session_id,
              error: error
            )

            {:error, error}

          {:error, reason} ->
            Logger.error("gRPC call to Rust Gateway failed",
              session_id: session_id,
              reason: inspect(reason)
            )

            {:error, {:grpc_error, reason}}
        end

      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end

  defp get_channel do
    # Get Rust Gateway gRPC endpoint from config
    host = Application.get_env(:msgr, :rust_gateway_host, "localhost")
    port = Application.get_env(:msgr, :rust_gateway_grpc_port, 50051)

    # TODO: Add connection pooling and reuse channels
    # For now, create a new channel for each request
    case GRPC.Stub.connect("#{host}:#{port}") do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} -> {:error, reason}
    end
  end
end
