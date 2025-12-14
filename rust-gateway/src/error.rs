use thiserror::Error;

#[derive(Error, Debug)]
pub enum NoiseError {
    #[error("Session not found: {0}")]
    SessionNotFound(String),

    #[error("Invalid session state: {0}")]
    InvalidState(String),

    #[error("Handshake builder failed: {0}")]
    BuilderFailed(String),

    #[error("Handshake processing failed: {0}")]
    HandshakeFailed(String),

    #[error("Transport transition failed: {0}")]
    TransportTransitionFailed(String),

    #[error("Handshake already complete")]
    HandshakeAlreadyComplete,

    #[error("Unknown handshake pattern: {0}")]
    UnknownPattern(String),

    #[error("Invalid token: {0}")]
    InvalidToken(String),

    #[error("Session expired")]
    SessionExpired,

    #[error("Internal error: {0}")]
    Internal(String),
}

#[derive(Error, Debug)]
pub enum CipherError {
    #[error("Session not found: {0}")]
    SessionNotFound(String),

    #[error("Handshake not complete")]
    HandshakeNotComplete,

    #[error("Encryption failed: {0}")]
    EncryptionFailed(String),

    #[error("Decryption failed: {0}")]
    DecryptionFailed(String),

    #[error("Nonce overflow")]
    NonceOverflow,
}

#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("Configuration file not found: {0}")]
    FileNotFound(String),

    #[error("Invalid configuration: {0}")]
    Invalid(String),

    #[error("Missing required field: {0}")]
    MissingField(String),

    #[error("Parse error: {0}")]
    ParseError(#[from] toml::de::Error),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

#[derive(Error, Debug)]
pub enum GatewayError {
    #[error("Noise error: {0}")]
    Noise(#[from] NoiseError),

    #[error("Cipher error: {0}")]
    Cipher(#[from] CipherError),

    #[error("Config error: {0}")]
    Config(#[from] ConfigError),

    #[error("gRPC error: {0}")]
    Grpc(#[from] tonic::Status),

    #[error("HTTP error: {0}")]
    Http(String),

    #[error("Internal error: {0}")]
    Internal(String),
}

impl From<NoiseError> for tonic::Status {
    fn from(err: NoiseError) -> Self {
        match err {
            NoiseError::SessionNotFound(_) => {
                tonic::Status::not_found(err.to_string())
            }
            NoiseError::InvalidState(_) | NoiseError::HandshakeAlreadyComplete => {
                tonic::Status::failed_precondition(err.to_string())
            }
            NoiseError::InvalidToken(_) => {
                tonic::Status::unauthenticated(err.to_string())
            }
            NoiseError::SessionExpired => {
                tonic::Status::deadline_exceeded("Session expired")
            }
            _ => tonic::Status::internal(err.to_string()),
        }
    }
}

// Axum error responses
impl axum::response::IntoResponse for GatewayError {
    fn into_response(self) -> axum::response::Response {
        use axum::http::StatusCode;
        use axum::Json;
        use serde_json::json;

        let (status, message) = match &self {
            GatewayError::Noise(NoiseError::SessionNotFound(_)) => {
                (StatusCode::NOT_FOUND, self.to_string())
            }
            GatewayError::Noise(NoiseError::InvalidToken(_)) => {
                (StatusCode::UNAUTHORIZED, self.to_string())
            }
            GatewayError::Noise(NoiseError::SessionExpired) => {
                (StatusCode::GONE, "Session expired".to_string())
            }
            GatewayError::Http(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            _ => (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error".to_string()),
        };

        (
            status,
            Json(json!({
                "error": message,
            })),
        )
            .into_response()
    }
}

pub type Result<T> = std::result::Result<T, GatewayError>;
