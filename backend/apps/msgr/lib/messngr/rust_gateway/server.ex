defmodule Messngr.RustGateway.Server do
  @moduledoc """
  gRPC server that handles requests from Rust Gateway.

  Primarily used for device validation during Noise handshakes.
  """

  use GRPC.Server, service: Noise.V1.NoiseBackend.Service

  alias Messngr.Accounts
  alias Noise.V1.{ValidateDeviceRequest, ValidateDeviceResponse}

  require Logger

  @doc """
  Validate a device public key.

  Called by Rust Gateway during Noise handshake to check if the device
  is registered and enabled.
  """
  def validate_device(%ValidateDeviceRequest{device_public_key: pubkey}, _stream) do
    Logger.debug("Validating device public key", pubkey_prefix: String.slice(pubkey, 0..16))

    case Accounts.get_device_by_public_key(pubkey) do
      %Accounts.Device{} = device ->
        Logger.info("Device validated successfully",
          device_id: device.id,
          account_id: device.account_id,
          enabled: device.enabled
        )

        %ValidateDeviceResponse{
          valid: device.enabled,
          device_id: device.id,
          account_id: device.account_id,
          profile_id: device.profile_id,
          enabled: device.enabled,
          error: if(device.enabled, do: nil, else: "Device is disabled")
        }

      nil ->
        Logger.warning("Device public key not found", pubkey_prefix: String.slice(pubkey, 0..16))

        %ValidateDeviceResponse{
          valid: false,
          device_id: nil,
          account_id: nil,
          profile_id: nil,
          enabled: nil,
          error: "Device not found"
        }
    end
  rescue
    error ->
      Logger.error("Error validating device",
        error: inspect(error),
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      %ValidateDeviceResponse{
        valid: false,
        error: "Internal server error: #{Exception.message(error)}"
      }
  end
end
