use crate::error::{NoiseError, Result};
use snow::{params::NoiseParams, Builder, HandshakeState};

/// Supported Noise handshake patterns
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HandshakePattern {
    /// Client knows server's public key
    NKpsk0,
    /// Mutual authentication, neither knows other's key
    XXpsk3,
    /// Client sends identity in first message
    IKpsk2,
}

impl HandshakePattern {
    /// Parse pattern from string
    pub fn from_str(s: &str) -> Result<Self> {
        match s {
            "NKpsk0" => Ok(Self::NKpsk0),
            "XXpsk3" => Ok(Self::XXpsk3),
            "IKpsk2" => Ok(Self::IKpsk2),
            _ => Err(NoiseError::UnknownPattern(s.to_string()).into()),
        }
    }

    /// Convert to string
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::NKpsk0 => "NKpsk0",
            Self::XXpsk3 => "XXpsk3",
            Self::IKpsk2 => "IKpsk2",
        }
    }

    /// Get Noise protocol parameters
    pub fn to_params(&self) -> NoiseParams {
        match self {
            Self::NKpsk0 => "Noise_NKpsk0_25519_AESGCM_SHA256".parse().unwrap(),
            Self::XXpsk3 => "Noise_XXpsk3_25519_AESGCM_SHA256".parse().unwrap(),
            Self::IKpsk2 => "Noise_IKpsk2_25519_AESGCM_SHA256".parse().unwrap(),
        }
    }

    /// Get PSK index for this pattern
    fn psk_index(&self) -> u8 {
        match self {
            Self::NKpsk0 => 0,
            Self::XXpsk3 => 3,
            Self::IKpsk2 => 2,
        }
    }

    /// Build initiator (client) handshake state
    pub fn build_initiator(
        &self,
        server_public_key: Option<&[u8]>,
        client_static_key: Option<&[u8]>,
        psk: &[u8],
    ) -> Result<HandshakeState> {
        let params = self.to_params();
        let mut builder = Builder::new(params);

        // Set remote public key (server) if known
        if let Some(key) = server_public_key {
            builder = builder.remote_public_key(key);
        }

        // Set local static key (client) if provided
        if let Some(key) = client_static_key {
            builder = builder.local_private_key(key);
        }

        // Set PSK
        builder = builder.psk(self.psk_index(), psk);

        builder
            .build_initiator()
            .map_err(|e| NoiseError::BuilderFailed(e.to_string()).into())
    }

    /// Build responder (server) handshake state
    pub fn build_responder(
        &self,
        server_static_key: &[u8],
        client_public_key: Option<&[u8]>,
        psk: &[u8],
    ) -> Result<HandshakeState> {
        let params = self.to_params();
        let mut builder = Builder::new(params);

        // Server always provides its static key
        builder = builder.local_private_key(server_static_key);

        // Set remote public key (client) if known (IK pattern)
        if let Some(key) = client_public_key {
            builder = builder.remote_public_key(key);
        }

        // Set PSK
        builder = builder.psk(self.psk_index(), psk);

        builder
            .build_responder()
            .map_err(|e| NoiseError::BuilderFailed(e.to_string()).into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pattern_parsing() {
        assert_eq!(HandshakePattern::from_str("NKpsk0").unwrap(), HandshakePattern::NKpsk0);
        assert_eq!(HandshakePattern::from_str("XXpsk3").unwrap(), HandshakePattern::XXpsk3);
        assert_eq!(HandshakePattern::from_str("IKpsk2").unwrap(), HandshakePattern::IKpsk2);
        assert!(HandshakePattern::from_str("Unknown").is_err());
    }

    #[test]
    fn test_pattern_to_string() {
        assert_eq!(HandshakePattern::NKpsk0.as_str(), "NKpsk0");
        assert_eq!(HandshakePattern::XXpsk3.as_str(), "XXpsk3");
        assert_eq!(HandshakePattern::IKpsk2.as_str(), "IKpsk2");
    }
}
