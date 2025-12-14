use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Session state - either handshaking or transport mode
pub enum SessionState {
    /// Handshake in progress
    Handshaking {
        state: snow::HandshakeState,
    },
    /// Handshake complete, ready for transport
    Transport {
        // Note: snow::TransportState is not Clone
        // Each session has unique transport state
        state: snow::TransportState,
    },
}

/// Session metadata (bound to account/profile after auth)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionMetadata {
    pub account_id: Option<String>,
    pub profile_id: Option<String>,
    pub device_id: Option<String>,
    pub handshake_hash: Vec<u8>,
    pub pattern: String,
}

/// Session entry in store
pub struct Session {
    pub id: Uuid,
    pub token: String,
    pub state: SessionState,
    pub metadata: SessionMetadata,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

impl Session {
    /// Check if session is expired
    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }

    /// Get remaining TTL in seconds
    pub fn remaining_ttl(&self) -> i64 {
        (self.expires_at - Utc::now()).num_seconds().max(0)
    }

    /// Get handshake hash
    pub fn handshake_hash(&self) -> Vec<u8> {
        self.metadata.handshake_hash.clone()
    }

    /// Bind account to session
    pub fn bind_account(&mut self, account_id: String, profile_id: Option<String>, device_id: Option<String>) {
        self.metadata.account_id = Some(account_id);
        self.metadata.profile_id = profile_id;
        self.metadata.device_id = device_id;
    }
}
