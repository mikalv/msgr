# Rust Noise Gateway - Implementasjonsguide

## Oversikt

Dette dokumentet beskriver den tekniske implementasjonen av Rust Noise Gateway, inkludert kodestruktur, algoritmer, og implementasjonsdetaljer.

## Prosjektstruktur

```
rust-gateway/
├── Cargo.toml
├── build.rs                    # Protobuf code generation
├── proto/
│   └── noise/
│       └── v1/
│           └── gateway.proto   # gRPC service definition
├── src/
│   ├── main.rs                # Entry point, server setup
│   ├── config.rs              # Configuration management
│   ├── server/
│   │   ├── mod.rs
│   │   ├── grpc.rs            # gRPC server implementation
│   │   ├── uds.rs             # Unix socket listener
│   │   └── mtls.rs            # mTLS listener
│   ├── noise/
│   │   ├── mod.rs
│   │   ├── handshake.rs       # Noise handshake logic
│   │   ├── session.rs         # Session management
│   │   ├── cipher.rs          # Encryption/decryption
│   │   └── patterns.rs        # Handshake pattern configs
│   ├── store/
│   │   ├── mod.rs
│   │   ├── memory.rs          # In-memory session store
│   │   └── ttl.rs             # TTL management
│   ├── service/
│   │   └── gateway.rs         # gRPC service implementation
│   ├── metrics/
│   │   └── mod.rs             # Prometheus metrics
│   └── error.rs               # Error types
└── tests/
    ├── integration/
    │   ├── handshake_test.rs
    │   └── session_test.rs
    └── unit/
        └── cipher_test.rs
```

## Core Components

### 1. Noise Handshake Implementation

#### Session State Machine

```rust
use snow::{Builder, HandshakeState, TransportState};
use dashmap::DashMap;
use uuid::Uuid;
use std::sync::Arc;
use tokio::time::{Duration, Instant};

/// Session state - kan være under handshake eller ferdig
pub enum SessionState {
    /// Handshake pågår
    Handshaking {
        state: HandshakeState,
        created_at: Instant,
        ttl: Duration,
    },
    /// Handshake ferdig, klar for transport
    Transport {
        tx: TransportState,  // Send cipher state
        rx: TransportState,  // Receive cipher state
        created_at: Instant,
        ttl: Duration,
        metadata: SessionMetadata,
    },
}

/// Session metadata (bindes til Account/Profile senere)
#[derive(Debug, Clone)]
pub struct SessionMetadata {
    pub account_id: Option<String>,
    pub profile_id: Option<String>,
    pub device_id: Option<String>,
    pub handshake_hash: Vec<u8>,
}

/// Session entry i store
pub struct Session {
    pub id: Uuid,
    pub token: String,  // Base64-encoded random token
    pub state: SessionState,
}

/// Session store (thread-safe)
pub struct SessionStore {
    sessions: Arc<DashMap<Uuid, Session>>,
    // Token -> Session ID mapping for fast lookup
    tokens: Arc<DashMap<String, Uuid>>,
}

impl SessionStore {
    pub fn new() -> Self {
        let store = Self {
            sessions: Arc::new(DashMap::new()),
            tokens: Arc::new(DashMap::new()),
        };

        // Start background cleanup task
        store.start_cleanup_task();
        store
    }

    /// Opprett ny session med handshake state
    pub fn create_session(
        &self,
        handshake_state: HandshakeState,
        ttl: Duration,
    ) -> (Uuid, String) {
        let id = Uuid::new_v4();
        let token = generate_session_token();

        let session = Session {
            id,
            token: token.clone(),
            state: SessionState::Handshaking {
                state: handshake_state,
                created_at: Instant::now(),
                ttl,
            },
        };

        self.sessions.insert(id, session);
        self.tokens.insert(token.clone(), id);

        (id, token)
    }

    /// Hent session by ID
    pub fn get_session(&self, id: &Uuid) -> Option<dashmap::mapref::one::Ref<Uuid, Session>> {
        self.sessions.get(id)
    }

    /// Hent session by token
    pub fn get_session_by_token(&self, token: &str) -> Option<dashmap::mapref::one::Ref<Uuid, Session>> {
        if let Some(entry) = self.tokens.get(token) {
            let id = *entry.value();
            drop(entry); // Release lock
            self.sessions.get(&id)
        } else {
            None
        }
    }

    /// Oppdater session til transport state
    pub fn complete_handshake(
        &self,
        id: &Uuid,
        transport: snow::TransportState,
        handshake_hash: Vec<u8>,
    ) -> Result<(), SessionError> {
        let mut session = self.sessions.get_mut(id)
            .ok_or(SessionError::NotFound)?;

        if let SessionState::Handshaking { created_at, ttl, .. } = session.state {
            // Split transport into tx/rx states
            let (mut tx, mut rx) = split_transport_state(transport);

            session.state = SessionState::Transport {
                tx,
                rx,
                created_at,
                ttl,
                metadata: SessionMetadata {
                    account_id: None,
                    profile_id: None,
                    device_id: None,
                    handshake_hash,
                },
            };
            Ok(())
        } else {
            Err(SessionError::InvalidState)
        }
    }

    /// Slett session
    pub fn delete_session(&self, id: &Uuid) -> bool {
        if let Some((_, session)) = self.sessions.remove(id) {
            self.tokens.remove(&session.token);
            true
        } else {
            false
        }
    }

    /// Background task for cleanup av expired sessions
    fn start_cleanup_task(&self) {
        let sessions = Arc::clone(&self.sessions);
        let tokens = Arc::clone(&self.tokens);

        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(60));

            loop {
                interval.tick().await;

                let now = Instant::now();
                let mut expired = Vec::new();

                // Find expired sessions
                for entry in sessions.iter() {
                    let (created_at, ttl) = match &entry.value().state {
                        SessionState::Handshaking { created_at, ttl, .. } => (created_at, ttl),
                        SessionState::Transport { created_at, ttl, .. } => (created_at, ttl),
                    };

                    if now.duration_since(*created_at) > *ttl {
                        expired.push(*entry.key());
                    }
                }

                // Remove expired sessions
                for id in expired {
                    if let Some((_, session)) = sessions.remove(&id) {
                        tokens.remove(&session.token);
                        tracing::info!(
                            session_id = %id,
                            "Session expired and removed"
                        );
                    }
                }
            }
        });
    }
}

/// Generate cryptographically secure session token
fn generate_session_token() -> String {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    let mut bytes = [0u8; 32];
    rng.fill(&mut bytes);
    base64::encode_config(bytes, base64::URL_SAFE_NO_PAD)
}

/// Split snow::TransportState into separate tx/rx states
/// Note: snow library doesn't support splitting, so we need to clone
fn split_transport_state(transport: snow::TransportState) -> (snow::TransportState, snow::TransportState) {
    // For now, we keep one transport state and clone for each operation
    // In production, we might need to implement manual nonce management
    // to ensure tx and rx use different nonce sequences
    (transport.clone(), transport)
}
```

#### Handshake Patterns

```rust
use snow::{Builder, params::NoiseParams};

pub enum HandshakePattern {
    NKpsk0,   // Client knows server's key, PSK
    XXpsk3,   // Mutual authentication, PSK
    IKpsk2,   // Client sends identity, PSK
}

impl HandshakePattern {
    /// Create Noise protocol parameters
    pub fn to_params(&self) -> NoiseParams {
        match self {
            Self::NKpsk0 => "Noise_NKpsk0_25519_AESGCM_SHA256".parse().unwrap(),
            Self::XXpsk3 => "Noise_XXpsk3_25519_AESGCM_SHA256".parse().unwrap(),
            Self::IKpsk2 => "Noise_IKpsk2_25519_AESGCM_SHA256".parse().unwrap(),
        }
    }

    /// Create builder for initiator (client)
    /// Client knows server's public key (for NK and IK patterns)
    pub fn build_initiator(
        &self,
        server_public_key: Option<&[u8]>,  // Required for NK and IK, not for XX
        client_static_key: Option<&[u8]>,  // Required for IK and XX
        psk: &[u8],
    ) -> Result<HandshakeState, NoiseError> {
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

        // Set PSK at appropriate index based on pattern
        let psk_index = match self {
            Self::NKpsk0 => 0,
            Self::XXpsk3 => 3,
            Self::IKpsk2 => 2,
        };
        builder = builder.psk(psk_index, psk);

        builder
            .build_initiator()
            .map_err(|e| NoiseError::BuilderFailed(e.to_string()))
    }

    /// Create builder for responder (server)
    pub fn build_responder(
        &self,
        server_static_key: &[u8],
        client_public_key: Option<&[u8]>,  // Only for IK pattern
        psk: &[u8],
    ) -> Result<HandshakeState, NoiseError> {
        let params = self.to_params();
        let mut builder = Builder::new(params);

        // Server always provides its static key
        builder = builder.local_private_key(server_static_key);

        // Set remote public key (client) if known (IK pattern)
        if let Some(key) = client_public_key {
            builder = builder.remote_public_key(key);
        }

        // Set PSK at appropriate index
        let psk_index = match self {
            Self::NKpsk0 => 0,
            Self::XXpsk3 => 3,
            Self::IKpsk2 => 2,
        };
        builder = builder.psk(psk_index, psk);

        builder
            .build_responder()
            .map_err(|e| NoiseError::BuilderFailed(e.to_string()))
    }
}
```

#### Handshake Processing

```rust
/// Process handshake message
pub async fn process_handshake_message(
    store: &SessionStore,
    session_id: &Uuid,
    message: &[u8],
) -> Result<ProcessHandshakeResponse, NoiseError> {
    let mut session = store.get_session_mut(session_id)
        .ok_or(NoiseError::SessionNotFound)?;

    match &mut session.state {
        SessionState::Handshaking { state, .. } => {
            let mut response_buf = vec![0u8; 65535];

            // Process incoming message
            let response_len = state.read_message(message, &mut response_buf)
                .map_err(|e| NoiseError::HandshakeFailed(e.to_string()))?;

            // Check if handshake is complete
            if state.is_handshake_finished() {
                // Transition to transport mode
                let transport = state.into_transport_mode()
                    .map_err(|e| NoiseError::TransportTransitionFailed(e.to_string()))?;

                let handshake_hash = state.get_handshake_hash().to_vec();

                drop(session); // Release lock
                store.complete_handshake(session_id, transport, handshake_hash)?;

                Ok(ProcessHandshakeResponse {
                    response_message: Some(response_buf[..response_len].to_vec()),
                    handshake_complete: true,
                })
            } else {
                // Handshake continues, send response
                Ok(ProcessHandshakeResponse {
                    response_message: Some(response_buf[..response_len].to_vec()),
                    handshake_complete: false,
                })
            }
        }
        SessionState::Transport { .. } => {
            Err(NoiseError::HandshakeAlreadyComplete)
        }
    }
}
```

### 2. Encryption/Decryption

```rust
use snow::TransportState;

/// Encrypt plaintext using Noise transport state
pub fn encrypt(
    transport: &mut TransportState,
    plaintext: &[u8],
) -> Result<Vec<u8>, CipherError> {
    let mut ciphertext = vec![0u8; plaintext.len() + 16]; // +16 for auth tag

    let len = transport.write_message(plaintext, &mut ciphertext)
        .map_err(|e| CipherError::EncryptionFailed(e.to_string()))?;

    ciphertext.truncate(len);
    Ok(ciphertext)
}

/// Decrypt ciphertext using Noise transport state
pub fn decrypt(
    transport: &mut TransportState,
    ciphertext: &[u8],
) -> Result<Vec<u8>, CipherError> {
    let mut plaintext = vec![0u8; ciphertext.len()];

    let len = transport.read_message(ciphertext, &mut plaintext)
        .map_err(|e| CipherError::DecryptionFailed(e.to_string()))?;

    plaintext.truncate(len);
    Ok(plaintext)
}

/// Encrypt with session lookup
pub async fn encrypt_with_session(
    store: &SessionStore,
    session_id: &Uuid,
    plaintext: &[u8],
) -> Result<Vec<u8>, CipherError> {
    let mut session = store.get_session_mut(session_id)
        .ok_or(CipherError::SessionNotFound)?;

    match &mut session.state {
        SessionState::Transport { tx, .. } => {
            encrypt(tx, plaintext)
        }
        SessionState::Handshaking { .. } => {
            Err(CipherError::HandshakeNotComplete)
        }
    }
}

/// Decrypt with session lookup
pub async fn decrypt_with_session(
    store: &SessionStore,
    session_id: &Uuid,
    ciphertext: &[u8],
) -> Result<Vec<u8>, CipherError> {
    let mut session = store.get_session_mut(session_id)
        .ok_or(CipherError::SessionNotFound)?;

    match &mut session.state {
        SessionState::Transport { rx, .. } => {
            decrypt(rx, ciphertext)
        }
        SessionState::Handshaking { .. } => {
            Err(CipherError::HandshakeNotComplete)
        }
    }
}
```

### 3. gRPC Service Implementation

```rust
use tonic::{Request, Response, Status};
use crate::proto::noise::v1::{
    noise_gateway_server::NoiseGateway,
    CreateHandshakeRequest, CreateHandshakeResponse,
    HandshakeMessageRequest, HandshakeMessageResponse,
    // ... other types
};

pub struct NoiseGatewayService {
    store: Arc<SessionStore>,
    server_key: Vec<u8>,  // Server's static private key
}

#[tonic::async_trait]
impl NoiseGateway for NoiseGatewayService {
    async fn create_handshake(
        &self,
        request: Request<CreateHandshakeRequest>,
    ) -> Result<Response<CreateHandshakeResponse>, Status> {
        let req = request.into_inner();

        // Parse pattern
        let pattern = match req.pattern.as_str() {
            "NKpsk0" => HandshakePattern::NKpsk0,
            "XXpsk3" => HandshakePattern::XXpsk3,
            "IKpsk2" => HandshakePattern::IKpsk2,
            _ => return Err(Status::invalid_argument("Unknown pattern")),
        };

        // Decode PSK
        let psk = base64::decode(&req.psk.unwrap_or_default())
            .map_err(|_| Status::invalid_argument("Invalid PSK"))?;

        // Build handshake state
        let handshake_state = if req.is_initiator {
            // Client initiator
            let server_pk = if req.pattern == "NKpsk0" || req.pattern == "IKpsk2" {
                Some(base64::decode(&req.server_public_key)
                    .map_err(|_| Status::invalid_argument("Invalid server public key"))?)
            } else {
                None  // XX pattern doesn't need server key
            };

            let client_key = if req.pattern == "XXpsk3" || req.pattern == "IKpsk2" {
                // For patterns where client sends identity, we need client's static key
                // This should be provided in the request or generated
                None  // TODO: Handle client key provision
            } else {
                None
            };

            pattern.build_initiator(
                server_pk.as_deref(),
                client_key.as_deref(),
                &psk
            )
        } else {
            // Server responder
            let client_pk = if req.pattern == "IKpsk2" {
                // For IK pattern, server might know client's key
                None  // TODO: Look up client key if available
            } else {
                None
            };

            pattern.build_responder(
                &self.server_key,
                client_pk.as_deref(),
                &psk
            )
        }.map_err(|e| Status::internal(format!("Handshake build failed: {}", e)))?;

        // Create session
        let ttl = Duration::from_secs(req.ttl_seconds.unwrap_or(300) as u64);
        let (session_id, token) = self.store.create_session(handshake_state, ttl);

        // Generate first message if initiator
        let handshake_message = if req.is_initiator {
            let mut buf = vec![0u8; 65535];
            let session = self.store.get_session_mut(&session_id).unwrap();
            if let SessionState::Handshaking { state, .. } = &mut session.state {
                let len = state.write_message(&[], &mut buf)
                    .map_err(|e| Status::internal(format!("Write message failed: {}", e)))?;
                Some(buf[..len].to_vec())
            } else {
                None
            }
        } else {
            None
        };

        // Generate signature (HMAC of handshake hash with token)
        let signature = generate_signature(&session_id, &token);

        Ok(Response::new(CreateHandshakeResponse {
            session_id: session_id.to_string(),
            handshake_message,
            session_token: token,
            expires_at: format_expiry_time(ttl),
            device_key: base64::encode(&self.get_server_public_key()),
            signature,
        }))
    }

    async fn process_handshake_message(
        &self,
        request: Request<HandshakeMessageRequest>,
    ) -> Result<Response<HandshakeMessageResponse>, Status> {
        let req = request.into_inner();

        let session_id = Uuid::parse_str(&req.session_id)
            .map_err(|_| Status::invalid_argument("Invalid session ID"))?;

        // Verify token
        if !self.verify_session_token(&session_id, &req.session_token) {
            return Err(Status::unauthenticated("Invalid session token"));
        }

        // Process message
        let response = process_handshake_message(&self.store, &session_id, &req.message)
            .await
            .map_err(|e| Status::internal(format!("Handshake processing failed: {}", e)))?;

        Ok(Response::new(HandshakeMessageResponse {
            response_message: response.response_message,
            handshake_complete: response.handshake_complete,
            session_token: req.session_token, // Same token
        }))
    }

    async fn encrypt(
        &self,
        request: Request<EncryptRequest>,
    ) -> Result<Response<EncryptResponse>, Status> {
        let req = request.into_inner();

        let session_id = Uuid::parse_str(&req.session_id)
            .map_err(|_| Status::invalid_argument("Invalid session ID"))?;

        if !self.verify_session_token(&session_id, &req.session_token) {
            return Err(Status::unauthenticated("Invalid session token"));
        }

        let ciphertext = encrypt_with_session(&self.store, &session_id, &req.plaintext)
            .await
            .map_err(|e| Status::internal(format!("Encryption failed: {}", e)))?;

        Ok(Response::new(EncryptResponse {
            ciphertext,
            nonce: vec![], // Nonce managed internally by snow
        }))
    }

    async fn decrypt(
        &self,
        request: Request<DecryptRequest>,
    ) -> Result<Response<DecryptResponse>, Status> {
        let req = request.into_inner();

        let session_id = Uuid::parse_str(&req.session_id)
            .map_err(|_| Status::invalid_argument("Invalid session ID"))?;

        if !self.verify_session_token(&session_id, &req.session_token) {
            return Err(Status::unauthenticated("Invalid session token"));
        }

        let plaintext = decrypt_with_session(&self.store, &session_id, &req.ciphertext)
            .await
            .map_err(|e| Status::internal(format!("Decryption failed: {}", e)))?;

        Ok(Response::new(DecryptResponse {
            plaintext,
        }))
    }

    // ... implement other methods (verify_token, delete_session, health)
}

impl NoiseGatewayService {
    fn verify_session_token(&self, session_id: &Uuid, token: &str) -> bool {
        if let Some(session) = self.store.get_session(session_id) {
            // Constant-time comparison
            use subtle::ConstantTimeEq;
            session.token.as_bytes().ct_eq(token.as_bytes()).into()
        } else {
            false
        }
    }

    fn get_server_public_key(&self) -> Vec<u8> {
        use x25519_dalek::{StaticSecret, PublicKey};
        let secret = StaticSecret::from(
            self.server_key.as_slice().try_into().unwrap()
        );
        PublicKey::from(&secret).to_bytes().to_vec()
    }
}
```

### 4. Server Setup

#### Unix Domain Socket

```rust
use tonic::transport::Server;
use tokio::net::UnixListener;
use tokio_stream::wrappers::UnixListenerStream;

pub async fn serve_uds(
    service: NoiseGatewayService,
    socket_path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // Remove old socket if exists
    let _ = std::fs::remove_file(socket_path);

    // Create directory if doesn't exist
    if let Some(parent) = std::path::Path::new(socket_path).parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Create Unix listener
    let listener = UnixListener::bind(socket_path)?;

    // Set socket permissions to 0600
    use std::os::unix::fs::PermissionsExt;
    let mut perms = std::fs::metadata(socket_path)?.permissions();
    perms.set_mode(0o600);
    std::fs::set_permissions(socket_path, perms)?;

    tracing::info!("gRPC server listening on unix://{}", socket_path);

    // Serve
    Server::builder()
        .add_service(NoiseGatewayServer::new(service))
        .serve_with_incoming(UnixListenerStream::new(listener))
        .await?;

    Ok(())
}
```

#### mTLS

```rust
use tonic::transport::{Server, ServerTlsConfig, Certificate, Identity};
use std::fs;

pub async fn serve_mtls(
    service: NoiseGatewayService,
    addr: &str,
    ca_cert_path: &str,
    server_cert_path: &str,
    server_key_path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // Load CA certificate
    let ca_cert = fs::read_to_string(ca_cert_path)?;
    let ca_cert = Certificate::from_pem(ca_cert);

    // Load server certificate and key
    let server_cert = fs::read_to_string(server_cert_path)?;
    let server_key = fs::read_to_string(server_key_path)?;
    let server_identity = Identity::from_pem(server_cert, server_key);

    // Configure mTLS
    let tls_config = ServerTlsConfig::new()
        .identity(server_identity)
        .client_ca_root(ca_cert);

    let addr = addr.parse()?;

    tracing::info!("gRPC server with mTLS listening on {}", addr);

    // Serve
    Server::builder()
        .tls_config(tls_config)?
        .add_service(NoiseGatewayServer::new(service))
        .serve(addr)
        .await?;

    Ok(())
}
```

### 5. Configuration

```rust
use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub transport: TransportConfig,
    pub server: ServerConfig,
    pub session: SessionConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "mode")]
pub enum TransportConfig {
    #[serde(rename = "uds")]
    UnixSocket {
        socket_path: PathBuf,
    },
    #[serde(rename = "mtls")]
    MutualTls {
        listen_addr: String,
        ca_cert: PathBuf,
        server_cert: PathBuf,
        server_key: PathBuf,
    },
}

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    pub server_static_key: String,  // Base64 or path to file
}

#[derive(Debug, Deserialize)]
pub struct SessionConfig {
    pub default_ttl_seconds: u64,
    pub cleanup_interval_seconds: u64,
}

#[derive(Debug, Deserialize)]
pub struct LoggingConfig {
    pub level: String,
    pub format: String,  // "json" or "pretty"
}

impl Config {
    pub fn from_file(path: &str) -> Result<Self, ConfigError> {
        let contents = std::fs::read_to_string(path)?;
        let config: Config = toml::from_str(&contents)?;
        Ok(config)
    }

    pub fn from_env() -> Result<Self, ConfigError> {
        // Load from environment variables
        let transport = match std::env::var("TRANSPORT_MODE")?.as_str() {
            "uds" => TransportConfig::UnixSocket {
                socket_path: PathBuf::from(
                    std::env::var("SOCKET_PATH")
                        .unwrap_or_else(|_| "/var/run/noise-gateway/noise.sock".to_string())
                ),
            },
            "mtls" => TransportConfig::MutualTls {
                listen_addr: std::env::var("LISTEN_ADDR")
                    .unwrap_or_else(|_| "0.0.0.0:50051".to_string()),
                ca_cert: PathBuf::from(std::env::var("TLS_CA")?),
                server_cert: PathBuf::from(std::env::var("TLS_CERT")?),
                server_key: PathBuf::from(std::env::var("TLS_KEY")?),
            },
            _ => return Err(ConfigError::InvalidTransportMode),
        };

        Ok(Config {
            transport,
            server: ServerConfig {
                server_static_key: std::env::var("SERVER_STATIC_KEY")?,
            },
            session: SessionConfig {
                default_ttl_seconds: std::env::var("SESSION_TTL")
                    .unwrap_or_else(|_| "300".to_string())
                    .parse()?,
                cleanup_interval_seconds: 60,
            },
            logging: LoggingConfig {
                level: std::env::var("RUST_LOG").unwrap_or_else(|_| "info".to_string()),
                format: std::env::var("LOG_FORMAT").unwrap_or_else(|_| "json".to_string()),
            },
        })
    }
}
```

### 6. Main Entry Point

```rust
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load configuration
    let config = Config::from_env()
        .or_else(|_| Config::from_file("config.toml"))?;

    // Setup logging
    init_logging(&config.logging)?;

    // Load server static key
    let server_key = load_server_key(&config.server.server_static_key)?;

    // Create session store
    let store = Arc::new(SessionStore::new());

    // Create gRPC service
    let service = NoiseGatewayService {
        store,
        server_key,
    };

    // Start metrics server
    tokio::spawn(serve_metrics());

    // Serve based on transport mode
    match config.transport {
        TransportConfig::UnixSocket { socket_path } => {
            serve_uds(service, socket_path.to_str().unwrap()).await?;
        }
        TransportConfig::MutualTls { listen_addr, ca_cert, server_cert, server_key } => {
            serve_mtls(
                service,
                &listen_addr,
                ca_cert.to_str().unwrap(),
                server_cert.to_str().unwrap(),
                server_key.to_str().unwrap(),
            ).await?;
        }
    }

    Ok(())
}

fn init_logging(config: &LoggingConfig) -> Result<(), Box<dyn std::error::Error>> {
    let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(&config.level));

    if config.format == "json" {
        tracing_subscriber::registry()
            .with(env_filter)
            .with(tracing_subscriber::fmt::layer().json())
            .init();
    } else {
        tracing_subscriber::registry()
            .with(env_filter)
            .with(tracing_subscriber::fmt::layer().pretty())
            .init();
    }

    Ok(())
}

async fn serve_metrics() -> Result<(), Box<dyn std::error::Error>> {
    use warp::Filter;

    let metrics_route = warp::path("metrics")
        .map(|| {
            use prometheus::{Encoder, TextEncoder};
            let encoder = TextEncoder::new();
            let metric_families = prometheus::gather();
            let mut buffer = vec![];
            encoder.encode(&metric_families, &mut buffer).unwrap();
            buffer
        });

    warp::serve(metrics_route)
        .run(([0, 0, 0, 0], 9090))
        .await;

    Ok(())
}

fn load_server_key(key_config: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    // Try to decode as base64 first
    if let Ok(key) = base64::decode(key_config) {
        return Ok(key);
    }

    // Otherwise, treat as file path
    let key_str = std::fs::read_to_string(key_config)?;
    let key = base64::decode(key_str.trim())?;
    Ok(key)
}
```

## Testing

### Unit Tests

```rust
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
    async fn test_handshake_nkpsk0() {
        let psk = b"test_psk_32_bytes_long_exactly!!";
        let server_key = x25519_dalek::StaticSecret::random_from_rng(&mut rand::thread_rng());
        let server_public = x25519_dalek::PublicKey::from(&server_key);

        // Client initiator (knows server's public key)
        let mut client = HandshakePattern::NKpsk0
            .build_initiator(
                Some(server_public.as_bytes()),
                None,  // Client doesn't provide static key for NK
                psk
            )
            .unwrap();

        // Server responder (doesn't know client's key)
        let mut server = HandshakePattern::NKpsk0
            .build_responder(
                server_key.to_bytes().as_ref(),
                None,  // Server doesn't know client's key
                psk
            )
            .unwrap();

        // Message 1: Client -> Server
        let mut buf1 = vec![0u8; 65535];
        let len1 = client.write_message(&[], &mut buf1).unwrap();
        let len2 = server.read_message(&buf1[..len1], &mut []).unwrap();

        // Message 2: Server -> Client
        let mut buf2 = vec![0u8; 65535];
        let len3 = server.write_message(&[], &mut buf2).unwrap();
        let len4 = client.read_message(&buf2[..len3], &mut []).unwrap();

        assert!(client.is_handshake_finished());
        assert!(server.is_handshake_finished());

        // Get handshake hashes (should match)
        let client_hash = client.get_handshake_hash();
        let server_hash = server.get_handshake_hash();
        assert_eq!(client_hash, server_hash);
    }

    #[tokio::test]
    async fn test_handshake_xxpsk3() {
        let psk = b"test_psk_32_bytes_long_exactly!!";

        // Generate keys for both parties
        let server_key = x25519_dalek::StaticSecret::random_from_rng(&mut rand::thread_rng());
        let client_key = x25519_dalek::StaticSecret::random_from_rng(&mut rand::thread_rng());

        // Client initiator (doesn't know server's key)
        let mut client = HandshakePattern::XXpsk3
            .build_initiator(
                None,  // Doesn't know server's key
                Some(client_key.to_bytes().as_ref()),  // Provides own key
                psk
            )
            .unwrap();

        // Server responder (doesn't know client's key)
        let mut server = HandshakePattern::XXpsk3
            .build_responder(
                server_key.to_bytes().as_ref(),
                None,  // Doesn't know client's key
                psk
            )
            .unwrap();

        // XX pattern is 3 messages
        // Message 1: Client -> Server
        let mut buf1 = vec![0u8; 65535];
        let len1 = client.write_message(&[], &mut buf1).unwrap();
        server.read_message(&buf1[..len1], &mut []).unwrap();

        // Message 2: Server -> Client
        let mut buf2 = vec![0u8; 65535];
        let len2 = server.write_message(&[], &mut buf2).unwrap();
        client.read_message(&buf2[..len2], &mut []).unwrap();

        // Message 3: Client -> Server
        let mut buf3 = vec![0u8; 65535];
        let len3 = client.write_message(&[], &mut buf3).unwrap();
        server.read_message(&buf3[..len3], &mut []).unwrap();

        assert!(client.is_handshake_finished());
        assert!(server.is_handshake_finished());

        // Get handshake hashes (should match)
        let client_hash = client.get_handshake_hash();
        let server_hash = server.get_handshake_hash();
        assert_eq!(client_hash, server_hash);
    }

    #[tokio::test]
    async fn test_encrypt_decrypt() {
        // Complete handshake first (abbreviated)
        let (mut client_transport, mut server_transport) = complete_handshake();

        let plaintext = b"Hello, Noise!";

        // Encrypt on client
        let mut ciphertext = vec![0u8; plaintext.len() + 16];
        let len = client_transport.write_message(plaintext, &mut ciphertext).unwrap();
        ciphertext.truncate(len);

        // Decrypt on server
        let mut decrypted = vec![0u8; ciphertext.len()];
        let len = server_transport.read_message(&ciphertext, &mut decrypted).unwrap();
        decrypted.truncate(len);

        assert_eq!(&decrypted, plaintext);
    }
}
```

### Integration Tests

```rust
#[cfg(test)]
mod integration_tests {
    use super::*;
    use tonic::Request;

    #[tokio::test]
    async fn test_full_handshake_flow() {
        let store = Arc::new(SessionStore::new());
        let server_key = x25519_dalek::StaticSecret::random();
        let service = NoiseGatewayService {
            store: Arc::clone(&store),
            server_key: server_key.to_bytes().to_vec(),
        };

        // Create handshake (server responder for NKpsk0)
        let create_req = CreateHandshakeRequest {
            pattern: "NKpsk0".to_string(),
            server_public_key: base64::encode(
                x25519_dalek::PublicKey::from(&server_key).as_bytes()
            ),
            psk: Some(base64::encode(b"test_psk_32_bytes_long_exactly!!")),
            ttl_seconds: Some(300),
            is_initiator: false,  // Server is responder
        };

        let create_resp = service.create_handshake(Request::new(create_req))
            .await
            .unwrap()
            .into_inner();

        assert!(!create_resp.session_id.is_empty());
        assert!(!create_resp.session_token.is_empty());

        // Verify session exists
        let session_id = Uuid::parse_str(&create_resp.session_id).unwrap();
        assert!(store.get_session(&session_id).is_some());
    }
}
```

## Error Handling

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum NoiseError {
    #[error("Session not found")]
    SessionNotFound,

    #[error("Invalid session state")]
    InvalidState,

    #[error("Handshake builder failed: {0}")]
    BuilderFailed(String),

    #[error("Handshake processing failed: {0}")]
    HandshakeFailed(String),

    #[error("Transport transition failed: {0}")]
    TransportTransitionFailed(String),

    #[error("Handshake already complete")]
    HandshakeAlreadyComplete,
}

#[derive(Error, Debug)]
pub enum CipherError {
    #[error("Session not found")]
    SessionNotFound,

    #[error("Handshake not complete")]
    HandshakeNotComplete,

    #[error("Encryption failed: {0}")]
    EncryptionFailed(String),

    #[error("Decryption failed: {0}")]
    DecryptionFailed(String),
}

// Convert to tonic::Status for gRPC
impl From<NoiseError> for tonic::Status {
    fn from(err: NoiseError) -> Self {
        match err {
            NoiseError::SessionNotFound => {
                tonic::Status::not_found("Session not found")
            }
            NoiseError::InvalidState => {
                tonic::Status::failed_precondition("Invalid session state")
            }
            _ => tonic::Status::internal(err.to_string()),
        }
    }
}
```

## Performance Optimizations

### 1. Connection Pooling (Elixir Side)

```elixir
# lib/msgr/noise_gateway/pool.ex
defmodule Messngr.NoiseGateway.Pool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, 10)
    transport = Keyword.get(opts, :transport, :uds)

    children = for i <- 1..pool_size do
      %{
        id: {:noise_gateway_worker, i},
        start: {Messngr.NoiseGateway.Worker, :start_link, [transport]}
      }
    end

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def checkout do
    # Get least loaded worker
    :poolboy.checkout(__MODULE__)
  end
end
```

### 2. Batch Operations

```rust
// Support batch encrypt/decrypt for better throughput
pub async fn encrypt_batch(
    store: &SessionStore,
    session_id: &Uuid,
    plaintexts: Vec<Vec<u8>>,
) -> Result<Vec<Vec<u8>>, CipherError> {
    let mut session = store.get_session_mut(session_id)
        .ok_or(CipherError::SessionNotFound)?;

    match &mut session.state {
        SessionState::Transport { tx, .. } => {
            plaintexts.into_iter()
                .map(|pt| encrypt(tx, &pt))
                .collect()
        }
        SessionState::Handshaking { .. } => {
            Err(CipherError::HandshakeNotComplete)
        }
    }
}
```

### 3. Zero-Copy with Shared Memory (Future)

```rust
// Future: Use shared memory for large payloads
use shared_memory::ShmemConf;

pub struct SharedMemoryTransport {
    shm: Shmem,
}

impl SharedMemoryTransport {
    pub fn write_encrypted(&mut self, ciphertext: &[u8]) -> Result<usize, Error> {
        unsafe {
            let ptr = self.shm.as_ptr();
            std::ptr::copy_nonoverlapping(
                ciphertext.as_ptr(),
                ptr,
                ciphertext.len()
            );
        }
        Ok(ciphertext.len())
    }
}
```

## Monitoring

### Prometheus Metrics

```rust
use prometheus::{IntCounter, IntGauge, Histogram, register_int_counter, register_int_gauge, register_histogram};

lazy_static! {
    static ref ACTIVE_SESSIONS: IntGauge = register_int_gauge!(
        "noise_gateway_active_sessions",
        "Number of active Noise sessions"
    ).unwrap();

    static ref HANDSHAKES_TOTAL: IntCounter = register_int_counter!(
        "noise_gateway_handshakes_total",
        "Total number of handshakes created"
    ).unwrap();

    static ref HANDSHAKES_FAILED: IntCounter = register_int_counter!(
        "noise_gateway_handshakes_failed_total",
        "Total number of failed handshakes"
    ).unwrap();

    static ref ENCRYPT_OPS: IntCounter = register_int_counter!(
        "noise_gateway_encrypt_operations_total",
        "Total number of encryption operations"
    ).unwrap();

    static ref DECRYPT_OPS: IntCounter = register_int_counter!(
        "noise_gateway_decrypt_operations_total",
        "Total number of decryption operations"
    ).unwrap();

    static ref REQUEST_DURATION: Histogram = register_histogram!(
        "noise_gateway_request_duration_seconds",
        "Request duration in seconds"
    ).unwrap();
}

// Usage in code
pub async fn create_handshake(...) -> Result<...> {
    let timer = REQUEST_DURATION.start_timer();
    HANDSHAKES_TOTAL.inc();

    let result = /* ... */;

    timer.observe_duration();

    if result.is_ok() {
        ACTIVE_SESSIONS.inc();
    } else {
        HANDSHAKES_FAILED.inc();
    }

    result
}
```

## Referanser

- [snow - Rust Noise Protocol](https://github.com/mcginty/snow)
- [tonic - Rust gRPC](https://github.com/hyperium/tonic)
- [DashMap - Concurrent HashMap](https://github.com/xacrimon/dashmap)
- [Noise Protocol Spec](http://www.noiseprotocol.org/noise.html)
