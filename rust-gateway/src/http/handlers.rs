use crate::error::Result;
use crate::noise::{create_handshake, HandshakePattern};
use crate::session::SessionStore;
use axum::{extract::State, http::StatusCode, Json};
use base64::Engine;
use chrono::Duration;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::debug;

/// Application state shared across HTTP handlers
#[derive(Clone)]
pub struct AppState {
    pub session_store: SessionStore,
    pub server_key: Vec<u8>,
    pub server_public_key: Vec<u8>,
    pub default_ttl: Duration,
}

/// Request to create a Noise handshake session
#[derive(Debug, Deserialize)]
pub struct CreateHandshakeRequest {
    /// Handshake pattern (NKpsk0, XXpsk3, IKpsk2)
    pub pattern: String,
    /// Pre-shared key (base64)
    pub psk: String,
    /// Optional TTL in seconds
    pub ttl_seconds: Option<i64>,
}

/// Response from creating a handshake session
#[derive(Debug, Serialize)]
pub struct CreateHandshakeResponse {
    /// Session ID (UUID)
    pub session_id: String,
    /// Session token for authentication
    pub session_token: String,
    /// First handshake message (base64, if server initiates)
    pub handshake_message: Option<String>,
    /// Signature (HMAC of handshake hash with token)
    pub signature: String,
    /// Server's device/public key (base64)
    pub device_key: String,
    /// Expiration time (ISO 8601)
    pub expires_at: String,
}

/// Create a new Noise handshake session
pub async fn create_handshake_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateHandshakeRequest>,
) -> Result<Json<CreateHandshakeResponse>> {
    debug!(pattern = %req.pattern, "Received handshake creation request");

    // Parse pattern
    let pattern = HandshakePattern::from_str(&req.pattern)?;

    // Decode PSK
    let psk = base64::prelude::BASE64_STANDARD
        .decode(&req.psk)
        .map_err(|e| crate::error::NoiseError::BuilderFailed(format!("Invalid PSK: {}", e)))?;

    // Determine TTL
    let ttl = if let Some(seconds) = req.ttl_seconds {
        Duration::seconds(seconds)
    } else {
        state.default_ttl
    };

    // Create handshake session
    let (session_id, token, first_message) = create_handshake(
        &state.session_store,
        pattern,
        &state.server_key,
        &psk,
        ttl,
    )
    .await?;

    // Generate signature (HMAC of session_id with token)
    let signature = generate_signature(&session_id.to_string(), &token);

    // Encode first message if present
    let handshake_message = first_message.map(|msg| base64::prelude::BASE64_STANDARD.encode(&msg));

    // Get expiration time
    let session = state.session_store.get_session(&session_id)?;
    let expires_at = session.expires_at.to_rfc3339();

    Ok(Json(CreateHandshakeResponse {
        session_id: session_id.to_string(),
        session_token: token,
        handshake_message,
        signature,
        device_key: base64::prelude::BASE64_STANDARD.encode(&state.server_public_key),
        expires_at,
    }))
}

/// Health check endpoint
pub async fn health_handler() -> StatusCode {
    StatusCode::OK
}

/// Metrics endpoint (placeholder - will be implemented with proper Prometheus exporter)
pub async fn metrics_handler() -> Result<String> {
    // TODO: Implement proper Prometheus metrics
    Ok("# Placeholder metrics\n".to_string())
}

/// Generate HMAC signature of data with key
fn generate_signature(data: &str, key: &str) -> String {
    use sha2::{Digest, Sha256};

    let mut hasher = Sha256::new();
    hasher.update(key.as_bytes());
    hasher.update(data.as_bytes());
    let result = hasher.finalize();

    base64::prelude::BASE64_STANDARD.encode(result)
}
