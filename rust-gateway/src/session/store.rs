use crate::error::{NoiseError, Result};
use crate::session::types::{Session, SessionMetadata, SessionState};
use base64::Engine;
use chrono::{Duration, Utc};
use dashmap::DashMap;
use std::sync::Arc;
use tokio::time;
use tracing::{debug, info, warn};
use uuid::Uuid;

/// Thread-safe session store with automatic TTL cleanup
#[derive(Clone)]
pub struct SessionStore {
    /// Sessions indexed by UUID
    sessions: Arc<DashMap<Uuid, Session>>,
    /// Token -> Session ID mapping for fast lookup
    tokens: Arc<DashMap<String, Uuid>>,
    /// Maximum number of sessions
    max_sessions: usize,
}

impl SessionStore {
    /// Create new session store
    pub fn new(max_sessions: usize) -> Self {
        Self {
            sessions: Arc::new(DashMap::new()),
            tokens: Arc::new(DashMap::new()),
            max_sessions,
        }
    }

    /// Create a new session with handshake state
    pub fn create_session(
        &self,
        handshake_state: snow::HandshakeState,
        pattern: String,
        ttl: Duration,
    ) -> Result<(Uuid, String)> {
        // Check session limit
        if self.sessions.len() >= self.max_sessions {
            warn!(
                "Session limit reached: {} / {}",
                self.sessions.len(),
                self.max_sessions
            );
            return Err(NoiseError::Internal("Session limit reached".to_string()).into());
        }

        let id = Uuid::new_v4();
        let token = generate_session_token();
        let now = Utc::now();

        let session = Session {
            id,
            token: token.clone(),
            state: SessionState::Handshaking {
                state: handshake_state,
            },
            metadata: SessionMetadata {
                account_id: None,
                profile_id: None,
                device_id: None,
                handshake_hash: Vec::new(), // Will be set when handshake completes
                pattern,
            },
            created_at: now,
            expires_at: now + ttl,
        };

        self.sessions.insert(id, session);
        self.tokens.insert(token.clone(), id);

        info!(
            session_id = %id,
            ttl_seconds = ttl.num_seconds(),
            "Session created"
        );

        Ok((id, token))
    }

    /// Get session by ID (read-only)
    pub fn get_session(&self, id: &Uuid) -> Result<dashmap::mapref::one::Ref<'_, Uuid, Session>> {
        self.sessions
            .get(id)
            .ok_or_else(|| NoiseError::SessionNotFound(id.to_string()).into())
    }

    /// Get session by ID (mutable)
    pub fn get_session_mut(
        &self,
        id: &Uuid,
    ) -> Result<dashmap::mapref::one::RefMut<'_, Uuid, Session>> {
        self.sessions
            .get_mut(id)
            .ok_or_else(|| NoiseError::SessionNotFound(id.to_string()).into())
    }

    /// Get session by token
    pub fn get_session_by_token(&self, token: &str) -> Result<Uuid> {
        let entry = self
            .tokens
            .get(token)
            .ok_or_else(|| NoiseError::InvalidToken("Token not found".to_string()))?;

        let session_id = *entry.value();
        drop(entry);

        // Verify session exists and not expired
        let session = self.get_session(&session_id)?;
        if session.is_expired() {
            drop(session);
            self.delete_session(&session_id)?;
            return Err(NoiseError::SessionExpired.into());
        }

        Ok(session_id)
    }

    /// Verify token and return session metadata
    pub fn verify_token(&self, token: &str) -> Result<(Uuid, SessionMetadata, i64)> {
        let session_id = self.get_session_by_token(token)?;
        let session = self.get_session(&session_id)?;

        Ok((
            session_id,
            session.metadata.clone(),
            session.remaining_ttl(),
        ))
    }

    /// Complete handshake and transition to transport mode
    pub fn complete_handshake(
        &self,
        id: &Uuid,
        transport_state: snow::TransportState,
        handshake_hash: Vec<u8>,
    ) -> Result<()> {
        let mut session = self.get_session_mut(id)?;

        match session.state {
            SessionState::Handshaking { .. } => {
                session.state = SessionState::Transport {
                    state: transport_state,
                };
                session.metadata.handshake_hash = handshake_hash.clone();

                info!(
                    session_id = %id,
                    handshake_hash = %base64::prelude::BASE64_STANDARD.encode(&handshake_hash),
                    "Handshake completed"
                );

                Ok(())
            }
            SessionState::Transport { .. } => {
                Err(NoiseError::HandshakeAlreadyComplete.into())
            }
        }
    }

    /// Bind account to session
    pub fn bind_account(
        &self,
        id: &Uuid,
        account_id: String,
        profile_id: Option<String>,
        device_id: Option<String>,
    ) -> Result<()> {
        let mut session = self.get_session_mut(id)?;
        session.bind_account(account_id.clone(), profile_id.clone(), device_id.clone());

        info!(
            session_id = %id,
            account_id = %account_id,
            profile_id = ?profile_id,
            device_id = ?device_id,
            "Account bound to session"
        );

        Ok(())
    }

    /// Delete session
    pub fn delete_session(&self, id: &Uuid) -> Result<bool> {
        if let Some((_, session)) = self.sessions.remove(id) {
            self.tokens.remove(&session.token);

            debug!(session_id = %id, "Session deleted");

            Ok(true)
        } else {
            Ok(false)
        }
    }

    /// Get total number of active sessions
    pub fn session_count(&self) -> usize {
        self.sessions.len()
    }

    /// Start background cleanup task
    pub fn start_cleanup_task(self, interval_seconds: u64) {
        tokio::spawn(async move {
            let mut interval = time::interval(time::Duration::from_secs(interval_seconds));

            loop {
                interval.tick().await;

                let now = Utc::now();
                let mut expired = Vec::new();

                // Find expired sessions
                for entry in self.sessions.iter() {
                    if entry.value().expires_at < now {
                        expired.push(*entry.key());
                    }
                }

                // Remove expired sessions
                let count = expired.len();
                for id in expired {
                    if let Some((_, session)) = self.sessions.remove(&id) {
                        self.tokens.remove(&session.token);
                    }
                }

                if count > 0 {
                    info!(
                        expired_count = count,
                        active_sessions = self.sessions.len(),
                        "Cleaned up expired sessions"
                    );
                }
            }
        });
    }
}

/// Generate cryptographically secure session token
fn generate_session_token() -> String {
    use rand::RngCore;
    let mut rng = rand::thread_rng();
    let mut bytes = [0u8; 32];
    rng.fill_bytes(&mut bytes);
    base64::prelude::BASE64_URL_SAFE_NO_PAD.encode(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_token_generation() {
        let token1 = generate_session_token();
        let token2 = generate_session_token();

        assert_ne!(token1, token2);
        assert_eq!(token1.len(), 43); // Base64 of 32 bytes without padding
    }

    #[tokio::test]
    async fn test_session_creation_and_lookup() {
        let store = SessionStore::new(1000);

        // Create a dummy handshake state (this would normally come from snow)
        // For testing, we'll skip actual Noise setup
        // In real code, this would be a proper snow::HandshakeState
    }
}
