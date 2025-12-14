use crate::error::{NoiseError, Result};
use crate::noise::patterns::HandshakePattern;
use crate::session::{SessionState, SessionStore};
use base64::Engine;
use chrono::Duration;
use tracing::{debug, info};
use uuid::Uuid;

/// Create a new Noise handshake session
pub async fn create_handshake(
    store: &SessionStore,
    pattern: HandshakePattern,
    server_static_key: &[u8],
    psk: &[u8],
    ttl: Duration,
) -> Result<(Uuid, String, Option<Vec<u8>>)> {
    debug!(
        pattern = pattern.as_str(),
        "Creating handshake session"
    );

    // Build responder handshake state (server side)
    let handshake_state = pattern.build_responder(server_static_key, None, psk)?;

    // Create session
    let (session_id, token) = store.create_session(handshake_state, pattern.as_str().to_string(), ttl)?;

    // For some patterns, server might send first message
    // For now, we assume client initiates (NKpsk0, XXpsk3, IKpsk2 all have client as initiator)
    let first_message = None;

    info!(
        session_id = %session_id,
        pattern = pattern.as_str(),
        "Handshake session created"
    );

    Ok((session_id, token, first_message))
}

/// Process a handshake message from client
pub async fn process_message(
    store: &SessionStore,
    session_id: &Uuid,
    message: &[u8],
) -> Result<ProcessMessageResponse> {
    let mut session = store.get_session_mut(session_id)?;

    match &mut session.state {
        SessionState::Handshaking { state } => {
            let mut response_buf = vec![0u8; 65535];

            // Read incoming message
            let response_len = state
                .read_message(message, &mut response_buf)
                .map_err(|e| NoiseError::HandshakeFailed(e.to_string()))?;

            let response_message = if response_len > 0 {
                Some(response_buf[..response_len].to_vec())
            } else {
                None
            };

            // Check if we need to write a response
            let needs_write = !state.is_my_turn();
            let write_message = if needs_write && !state.is_handshake_finished() {
                let mut write_buf = vec![0u8; 65535];
                let write_len = state
                    .write_message(&[], &mut write_buf)
                    .map_err(|e| NoiseError::HandshakeFailed(e.to_string()))?;
                Some(write_buf[..write_len].to_vec())
            } else {
                response_message
            };

            // Check if handshake is complete
            if state.is_handshake_finished() {
                // Get handshake hash before transitioning
                let handshake_hash = state.get_handshake_hash().to_vec();

                // We need to move the handshake state out to transition it
                // Create a temporary invalid state for replacement
                let temp_state = snow::Builder::new("Noise_NN_25519_AESGCM_SHA256".parse().unwrap())
                    .build_responder()
                    .unwrap(); // This is just a placeholder

                // Replace the state with temp, getting ownership of the real state
                let old_state = std::mem::replace(state, temp_state);

                // Now transition the owned handshake state
                let transport = old_state
                    .into_transport_mode()
                    .map_err(|e| NoiseError::TransportTransitionFailed(e.to_string()))?;

                // Drop session lock before calling store
                drop(session);

                // Complete the handshake with new transport state
                store.complete_handshake(session_id, transport, handshake_hash.clone())?;

                info!(
                    session_id = %session_id,
                    handshake_hash = %base64::prelude::BASE64_STANDARD.encode(&handshake_hash),
                    "Handshake completed successfully"
                );

                Ok(ProcessMessageResponse {
                    response_message: write_message,
                    handshake_complete: true,
                })
            } else {
                debug!(
                    session_id = %session_id,
                    "Handshake in progress"
                );

                Ok(ProcessMessageResponse {
                    response_message: write_message,
                    handshake_complete: false,
                })
            }
        }
        SessionState::Transport { .. } => {
            Err(NoiseError::HandshakeAlreadyComplete.into())
        }
    }
}

/// Response from processing a handshake message
pub struct ProcessMessageResponse {
    pub response_message: Option<Vec<u8>>,
    pub handshake_complete: bool,
}

/// Encrypt data using transport state
pub async fn encrypt(
    store: &SessionStore,
    session_id: &Uuid,
    plaintext: &[u8],
) -> Result<Vec<u8>> {
    let mut session = store.get_session_mut(session_id)?;

    match &mut session.state {
        SessionState::Transport { state } => {
            let mut ciphertext = vec![0u8; plaintext.len() + 16]; // +16 for auth tag

            let len = state
                .write_message(plaintext, &mut ciphertext)
                .map_err(|e| NoiseError::HandshakeFailed(format!("Encryption failed: {}", e)))?;

            ciphertext.truncate(len);
            Ok(ciphertext)
        }
        SessionState::Handshaking { .. } => {
            Err(NoiseError::InvalidState("Handshake not complete".to_string()).into())
        }
    }
}

/// Decrypt data using transport state
pub async fn decrypt(
    store: &SessionStore,
    session_id: &Uuid,
    ciphertext: &[u8],
) -> Result<Vec<u8>> {
    let mut session = store.get_session_mut(session_id)?;

    match &mut session.state {
        SessionState::Transport { state } => {
            let mut plaintext = vec![0u8; ciphertext.len()];

            let len = state
                .read_message(ciphertext, &mut plaintext)
                .map_err(|e| NoiseError::HandshakeFailed(format!("Decryption failed: {}", e)))?;

            plaintext.truncate(len);
            Ok(plaintext)
        }
        SessionState::Handshaking { .. } => {
            Err(NoiseError::InvalidState("Handshake not complete".to_string()).into())
        }
    }
}
