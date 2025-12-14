use super::handlers::{create_handshake_handler, health_handler, metrics_handler, AppState};
use crate::proxy::{proxy_handler, ProxyClient, ProxyState};
use crate::session::SessionStore;
use axum::{
    routing::{any, get, post},
    Router,
};
use std::{sync::Arc, time::Duration};
use tower_http::{
    compression::CompressionLayer,
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

/// Create HTTP router with reverse proxy
pub fn create_router(
    noise_state: Arc<AppState>,
    session_store: SessionStore,
    backend_url: String,
) -> Router {
    // Create proxy client
    let proxy_client = ProxyClient::new(backend_url, Duration::from_secs(30));

    // Create proxy state
    let proxy_state = Arc::new(ProxyState {
        session_store,
        proxy_client,
    });

    Router::new()
        // Noise-specific endpoints (handle internally)
        .route("/noise/handshake", post(create_handshake_handler))
        .with_state(noise_state)
        // Gateway-specific endpoints
        .route("/gateway/health", get(health_handler))
        .route("/gateway/metrics", get(metrics_handler))
        // Reverse proxy for ALL other routes
        // This catches /api/*, /socket, /health, etc and forwards to Elixir
        .fallback(any(proxy_handler))
        .with_state(proxy_state)
        // Middleware
        .layer(CompressionLayer::new())
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .layer(TraceLayer::new_for_http())
}
