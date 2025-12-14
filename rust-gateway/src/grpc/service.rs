use crate::session::SessionStore;
use tonic::{Request, Response, Status};
use tracing::{debug, info};

// Include generated protobuf code
pub mod proto {
    tonic::include_proto!("noise.v1");
}

use proto::{
    noise_backend_server::NoiseBackend, BindAccountRequest, BindAccountResponse,
    DeleteSessionRequest, DeleteSessionResponse, HealthRequest, HealthResponse, SessionAck,
    SessionNotification, ValidateDeviceRequest, ValidateDeviceResponse,
    VerifyTokenRequest, VerifyTokenResponse, SessionMetadata as ProtoSessionMetadata,
};

/// gRPC service implementation for Elixir backend communication
pub struct NoiseBackendService {
    session_store: SessionStore,
    start_time: std::time::Instant,
    elixir_backend_url: Option<String>,
}

impl NoiseBackendService {
    pub fn new(session_store: SessionStore, elixir_backend_url: Option<String>) -> Self {
        Self {
            session_store,
            start_time: std::time::Instant::now(),
            elixir_backend_url,
        }
    }
}

#[tonic::async_trait]
impl NoiseBackend for NoiseBackendService {
    async fn notify_new_session(
        &self,
        request: Request<SessionNotification>,
    ) -> Result<Response<SessionAck>, Status> {
        let notification = request.into_inner();

        info!(
            session_id = %notification.session_id,
            pattern = %notification.pattern,
            "Received session notification from backend"
        );

        // TODO: Store notification metadata if needed
        // For now, we just acknowledge

        Ok(Response::new(SessionAck { acknowledged: true }))
    }

    async fn verify_token(
        &self,
        request: Request<VerifyTokenRequest>,
    ) -> Result<Response<VerifyTokenResponse>, Status> {
        let req = request.into_inner();

        debug!(token_prefix = &req.session_token[..8.min(req.session_token.len())], "Verifying token");

        match self.session_store.verify_token(&req.session_token) {
            Ok((session_id, metadata, remaining_ttl)) => {
                info!(
                    session_id = %session_id,
                    remaining_ttl = remaining_ttl,
                    "Token verified successfully"
                );

                Ok(Response::new(VerifyTokenResponse {
                    valid: true,
                    session_id: Some(session_id.to_string()),
                    remaining_ttl: Some(remaining_ttl as i32),
                    metadata: Some(ProtoSessionMetadata {
                        account_id: metadata.account_id,
                        profile_id: metadata.profile_id,
                        device_id: metadata.device_id,
                        handshake_hash: metadata.handshake_hash,
                        pattern: metadata.pattern,
                    }),
                }))
            }
            Err(e) => {
                debug!(error = %e, "Token verification failed");

                Ok(Response::new(VerifyTokenResponse {
                    valid: false,
                    session_id: None,
                    remaining_ttl: None,
                    metadata: None,
                }))
            }
        }
    }

    async fn validate_device(
        &self,
        request: Request<ValidateDeviceRequest>,
    ) -> Result<Response<ValidateDeviceResponse>, Status> {
        let req = request.into_inner();

        debug!(device_public_key_prefix = &req.device_public_key[..16.min(req.device_public_key.len())],
               "Validating device public key");

        // Call Elixir backend to validate device
        match &self.elixir_backend_url {
            Some(url) => {
                // Connect to Elixir and validate
                match super::client::ElixirBackendClient::connect(url).await {
                    Ok(mut client) => {
                        match client.validate_device(req.device_public_key.clone()).await {
                            Ok(device_info) => {
                                info!(
                                    valid = device_info.valid,
                                    device_id = ?device_info.device_id,
                                    "Device validation completed"
                                );

                                Ok(Response::new(ValidateDeviceResponse {
                                    valid: device_info.valid,
                                    device_id: device_info.device_id,
                                    account_id: device_info.account_id,
                                    profile_id: device_info.profile_id,
                                    enabled: Some(device_info.enabled),
                                    error: None,
                                }))
                            }
                            Err(e) => {
                                debug!(error = %e, "Failed to validate device");
                                Ok(Response::new(ValidateDeviceResponse {
                                    valid: false,
                                    device_id: None,
                                    account_id: None,
                                    profile_id: None,
                                    enabled: None,
                                    error: Some(format!("Validation error: {}", e)),
                                }))
                            }
                        }
                    }
                    Err(e) => {
                        debug!(error = %e, "Failed to connect to Elixir backend");
                        Ok(Response::new(ValidateDeviceResponse {
                            valid: false,
                            device_id: None,
                            account_id: None,
                            profile_id: None,
                            enabled: None,
                            error: Some(format!("Connection error: {}", e)),
                        }))
                    }
                }
            }
            None => {
                // Elixir backend not configured - skip validation
                debug!("Elixir backend URL not configured, skipping device validation");
                Ok(Response::new(ValidateDeviceResponse {
                    valid: true, // Allow by default if not configured
                    device_id: None,
                    account_id: None,
                    profile_id: None,
                    enabled: Some(true),
                    error: None,
                }))
            }
        }
    }

    async fn bind_account(
        &self,
        request: Request<BindAccountRequest>,
    ) -> Result<Response<BindAccountResponse>, Status> {
        let req = request.into_inner();

        let session_id = uuid::Uuid::parse_str(&req.session_id)
            .map_err(|e| Status::invalid_argument(format!("Invalid session ID: {}", e)))?;

        // Verify token matches session
        let token_session_id = self
            .session_store
            .get_session_by_token(&req.session_token)
            .map_err(|e| Status::unauthenticated(format!("Invalid token: {}", e)))?;

        if token_session_id != session_id {
            return Ok(Response::new(BindAccountResponse {
                success: false,
                error: Some("Token does not match session".to_string()),
            }));
        }

        // Bind account
        self.session_store
            .bind_account(&session_id, req.account_id.clone(), req.profile_id, req.device_id)
            .map_err(|e| Status::internal(format!("Failed to bind account: {}", e)))?;

        info!(
            session_id = %session_id,
            account_id = %req.account_id,
            "Account bound to session"
        );

        Ok(Response::new(BindAccountResponse {
            success: true,
            error: None,
        }))
    }

    async fn delete_session(
        &self,
        request: Request<DeleteSessionRequest>,
    ) -> Result<Response<DeleteSessionResponse>, Status> {
        let req = request.into_inner();

        let session_id = uuid::Uuid::parse_str(&req.session_id)
            .map_err(|e| Status::invalid_argument(format!("Invalid session ID: {}", e)))?;

        let deleted = self
            .session_store
            .delete_session(&session_id)
            .map_err(|e| Status::internal(format!("Failed to delete session: {}", e)))?;

        info!(
            session_id = %session_id,
            deleted = deleted,
            "Session deletion requested"
        );

        Ok(Response::new(DeleteSessionResponse { deleted }))
    }

    async fn health(
        &self,
        _request: Request<HealthRequest>,
    ) -> Result<Response<HealthResponse>, Status> {
        let uptime = self.start_time.elapsed().as_secs();

        Ok(Response::new(HealthResponse {
            status: "SERVING".to_string(),
            active_sessions: self.session_store.session_count() as u64,
            uptime_seconds: uptime,
        }))
    }
}
