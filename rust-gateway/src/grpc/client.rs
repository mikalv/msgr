use super::service::proto::{
    noise_backend_client::NoiseBackendClient, ValidateDeviceRequest,
};
use crate::error::{GatewayError, Result};
use tonic::transport::Channel;
use tracing::{debug, error, info};

/// gRPC client for calling Elixir backend
pub struct ElixirBackendClient {
    client: NoiseBackendClient<Channel>,
}

impl ElixirBackendClient {
    /// Create a new client connected to Elixir backend
    pub async fn connect(endpoint: &str) -> Result<Self> {
        info!(endpoint = %endpoint, "Connecting to Elixir backend");

        let client = NoiseBackendClient::connect(endpoint.to_string())
            .await
            .map_err(|e| {
                error!(error = %e, "Failed to connect to Elixir backend");
                GatewayError::Internal(format!("Failed to connect to Elixir: {}", e))
            })?;

        info!("Successfully connected to Elixir backend");

        Ok(Self { client })
    }

    /// Validate a device public key against Elixir database
    pub async fn validate_device(&mut self, device_public_key: String) -> Result<DeviceInfo> {
        debug!(
            device_public_key_prefix = &device_public_key[..16.min(device_public_key.len())],
            "Validating device with Elixir backend"
        );

        let request = tonic::Request::new(ValidateDeviceRequest {
            device_public_key: device_public_key.clone(),
        });

        let response = self
            .client
            .validate_device(request)
            .await
            .map_err(|e| {
                error!(error = %e, "gRPC call to Elixir failed");
                GatewayError::Internal(format!("ValidateDevice failed: {}", e))
            })?
            .into_inner();

        if response.valid {
            info!(
                device_id = ?response.device_id,
                account_id = ?response.account_id,
                "Device validated successfully"
            );

            Ok(DeviceInfo {
                valid: true,
                device_id: response.device_id,
                account_id: response.account_id,
                profile_id: response.profile_id,
                enabled: response.enabled.unwrap_or(false),
            })
        } else {
            debug!(
                error = ?response.error,
                "Device validation failed"
            );

            Ok(DeviceInfo {
                valid: false,
                device_id: None,
                account_id: None,
                profile_id: None,
                enabled: false,
            })
        }
    }
}

/// Device information returned from Elixir
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub valid: bool,
    pub device_id: Option<String>,
    pub account_id: Option<String>,
    pub profile_id: Option<String>,
    pub enabled: bool,
}
