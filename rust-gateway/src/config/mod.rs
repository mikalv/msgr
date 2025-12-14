use crate::error::{ConfigError, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Config {
    pub server: ServerConfig,
    pub transport: TransportConfig,
    pub session: SessionConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ServerConfig {
    /// HTTP port for client-facing API
    pub http_port: u16,
    /// gRPC port for internal communication
    pub grpc_port: u16,
    /// Server's static private key (base64 or file path)
    pub server_static_key: String,
    /// Server's static public key (base64 or file path, optional - derived from private)
    pub server_public_key: Option<String>,
    /// Backend URL to proxy to (e.g. http://localhost:4000)
    pub backend_url: String,
    /// Proxy timeout in seconds
    pub proxy_timeout: Option<u64>,
    /// Elixir gRPC backend URL for device validation
    pub elixir_grpc_url: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "mode")]
pub enum TransportConfig {
    #[serde(rename = "uds")]
    UnixSocket {
        socket_path: String,
    },
    #[serde(rename = "mtls")]
    MutualTls {
        listen_addr: String,
        ca_cert: String,
        server_cert: String,
        server_key: String,
    },
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct SessionConfig {
    /// Default TTL for sessions in seconds
    pub default_ttl_seconds: u64,
    /// Cleanup interval in seconds
    pub cleanup_interval_seconds: u64,
    /// Maximum number of concurrent sessions
    pub max_sessions: usize,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LoggingConfig {
    /// Log level: trace, debug, info, warn, error
    pub level: String,
    /// Log format: json, pretty
    pub format: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            server: ServerConfig {
                http_port: 8443,
                grpc_port: 50051,
                server_static_key: String::new(),
                server_public_key: None,
                backend_url: "http://localhost:4000".to_string(),
                proxy_timeout: Some(30),
                elixir_grpc_url: Some("http://localhost:50052".to_string()),
            },
            transport: TransportConfig::UnixSocket {
                socket_path: "/var/run/noise-gateway/noise.sock".to_string(),
            },
            session: SessionConfig {
                default_ttl_seconds: 300,
                cleanup_interval_seconds: 60,
                max_sessions: 1_000_000,
            },
            logging: LoggingConfig {
                level: "info".to_string(),
                format: "json".to_string(),
            },
        }
    }
}

impl Config {
    /// Load configuration from file
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let contents = std::fs::read_to_string(path.as_ref())
            .map_err(|e| ConfigError::FileNotFound(e.to_string()))?;
        let config: Config = toml::from_str(&contents)
            .map_err(ConfigError::ParseError)?;
        config.validate()?;
        Ok(config)
    }

    /// Load configuration from environment variables
    pub fn from_env() -> Result<Self> {
        let transport = match std::env::var("TRANSPORT_MODE")
            .unwrap_or_else(|_| "uds".to_string())
            .as_str()
        {
            "uds" => TransportConfig::UnixSocket {
                socket_path: std::env::var("SOCKET_PATH")
                    .unwrap_or_else(|_| "/var/run/noise-gateway/noise.sock".to_string()),
            },
            "mtls" => TransportConfig::MutualTls {
                listen_addr: std::env::var("LISTEN_ADDR")
                    .unwrap_or_else(|_| "0.0.0.0:50051".to_string()),
                ca_cert: std::env::var("TLS_CA")
                    .map_err(|_| ConfigError::MissingField("TLS_CA".to_string()))?,
                server_cert: std::env::var("TLS_CERT")
                    .map_err(|_| ConfigError::MissingField("TLS_CERT".to_string()))?,
                server_key: std::env::var("TLS_KEY")
                    .map_err(|_| ConfigError::MissingField("TLS_KEY".to_string()))?,
            },
            mode => {
                return Err(ConfigError::Invalid(format!("Unknown transport mode: {}", mode)).into())
            }
        };

        let config = Config {
            server: ServerConfig {
                http_port: std::env::var("HTTP_PORT")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(8443),
                grpc_port: std::env::var("GRPC_PORT")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(50051),
                server_static_key: std::env::var("SERVER_STATIC_KEY")
                    .map_err(|_| ConfigError::MissingField("SERVER_STATIC_KEY".to_string()))?,
                server_public_key: std::env::var("SERVER_PUBLIC_KEY").ok(),
                backend_url: std::env::var("BACKEND_URL")
                    .unwrap_or_else(|_| "http://localhost:4000".to_string()),
                proxy_timeout: std::env::var("PROXY_TIMEOUT")
                    .ok()
                    .and_then(|s| s.parse().ok()),
                elixir_grpc_url: std::env::var("ELIXIR_GRPC_URL").ok(),
            },
            transport,
            session: SessionConfig {
                default_ttl_seconds: std::env::var("SESSION_TTL")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(300),
                cleanup_interval_seconds: std::env::var("CLEANUP_INTERVAL")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(60),
                max_sessions: std::env::var("MAX_SESSIONS")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(1_000_000),
            },
            logging: LoggingConfig {
                level: std::env::var("RUST_LOG").unwrap_or_else(|_| "info".to_string()),
                format: std::env::var("LOG_FORMAT").unwrap_or_else(|_| "json".to_string()),
            },
        };

        config.validate()?;
        Ok(config)
    }

    /// Validate configuration
    fn validate(&self) -> Result<()> {
        if self.server.server_static_key.is_empty() {
            return Err(ConfigError::MissingField("server_static_key".to_string()).into());
        }

        if self.session.default_ttl_seconds == 0 {
            return Err(ConfigError::Invalid("default_ttl_seconds must be > 0".to_string()).into());
        }

        if self.session.cleanup_interval_seconds == 0 {
            return Err(
                ConfigError::Invalid("cleanup_interval_seconds must be > 0".to_string()).into(),
            );
        }

        Ok(())
    }

    /// Load server static key from config
    pub fn load_server_key(&self) -> Result<Vec<u8>> {
        load_key(&self.server.server_static_key)
    }

    /// Get or derive server public key
    pub fn get_server_public_key(&self) -> Result<Vec<u8>> {
        if let Some(ref pk) = self.server.server_public_key {
            return load_key(pk);
        }

        // Derive from private key
        let private_key = self.load_server_key()?;
        if private_key.len() != 32 {
            return Err(ConfigError::Invalid("Server key must be 32 bytes".to_string()).into());
        }

        let secret = x25519_dalek::StaticSecret::from(
            <[u8; 32]>::try_from(private_key.as_slice())
                .map_err(|_| ConfigError::Invalid("Invalid key length".to_string()))?,
        );
        let public = x25519_dalek::PublicKey::from(&secret);

        Ok(public.as_bytes().to_vec())
    }
}

/// Load key from base64 string or file path
fn load_key(key_config: &str) -> Result<Vec<u8>> {
    use base64::Engine;

    // Try to decode as base64 first
    if let Ok(key) = base64::prelude::BASE64_STANDARD.decode(key_config) {
        return Ok(key);
    }

    // Otherwise, treat as file path
    let key_str = std::fs::read_to_string(key_config)
        .map_err(|e| ConfigError::FileNotFound(format!("Key file: {}", e)))?;

    base64::prelude::BASE64_STANDARD
        .decode(key_str.trim())
        .map_err(|e| ConfigError::Invalid(format!("Invalid base64 in key file: {}", e)).into())
}
