use base64::Engine;
use chrono::Duration;
use rust_gateway::{config::Config, grpc::NoiseBackendService, http, SessionStore};
use std::sync::Arc;
use tonic::transport::Server;
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load environment variables from .env if present
    dotenvy::dotenv().ok();

    // Load configuration
    let config = Config::from_env()
        .or_else(|_| Config::from_file("config.toml"))
        .unwrap_or_else(|e| {
            eprintln!("Failed to load configuration: {}", e);
            eprintln!("Using default configuration");
            Config::default()
        });

    // Initialize logging
    init_logging(&config)?;

    info!("Starting Noise Gateway...");
    info!(
        http_port = config.server.http_port,
        grpc_port = config.server.grpc_port,
        "Configuration loaded"
    );

    // Load server keys
    let server_key = config.load_server_key()?;
    let server_public_key = config.get_server_public_key()?;

    info!(
        public_key = %base64::prelude::BASE64_STANDARD.encode(&server_public_key),
        "Server keys loaded"
    );

    // Create session store
    let session_store = SessionStore::new(config.session.max_sessions);

    // Start cleanup task
    let cleanup_store = session_store.clone();
    cleanup_store.start_cleanup_task(config.session.cleanup_interval_seconds);

    info!(
        max_sessions = config.session.max_sessions,
        cleanup_interval = config.session.cleanup_interval_seconds,
        "Session store initialized"
    );

    // Create HTTP app state
    let http_state = Arc::new(http::handlers::AppState {
        session_store: session_store.clone(),
        server_key: server_key.clone(),
        server_public_key: server_public_key.clone(),
        default_ttl: Duration::seconds(config.session.default_ttl_seconds as i64),
    });

    // Create HTTP router with reverse proxy
    let http_router = http::create_router(
        http_state,
        session_store.clone(),
        config.server.backend_url.clone(),
    );

    // Create gRPC service
    let grpc_service = NoiseBackendService::new(
        session_store.clone(),
        config.server.elixir_grpc_url.clone(),
    );

    // Spawn HTTP server
    let http_port = config.server.http_port;
    let http_handle = tokio::spawn(async move {
        let addr: std::net::SocketAddr = format!("0.0.0.0:{}", http_port).parse().unwrap();

        info!(addr = %addr, "HTTP server listening");

        axum::serve(
            tokio::net::TcpListener::bind(addr).await.unwrap(),
            http_router,
        )
        .await
        .unwrap();
    });

    // Spawn gRPC server
    let grpc_port = config.server.grpc_port;
    let grpc_handle = tokio::spawn(async move {
        let addr: std::net::SocketAddr = format!("0.0.0.0:{}", grpc_port).parse().unwrap();

        info!(addr = %addr, "gRPC server listening");

        Server::builder()
            .add_service(
                rust_gateway::grpc::service::proto::noise_backend_server::NoiseBackendServer::new(
                    grpc_service,
                ),
            )
            .serve(addr)
            .await
            .unwrap();
    });

    info!("Noise Gateway started successfully");
    info!("HTTP API: http://0.0.0.0:{}", config.server.http_port);
    info!("gRPC API: http://0.0.0.0:{}", config.server.grpc_port);

    // Wait for both servers
    tokio::select! {
        res = http_handle => {
            if let Err(e) = res {
                error!("HTTP server error: {}", e);
            }
        }
        res = grpc_handle => {
            if let Err(e) = res {
                error!("gRPC server error: {}", e);
            }
        }
    }

    Ok(())
}

fn init_logging(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(&config.logging.level));

    if config.logging.format == "json" {
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
