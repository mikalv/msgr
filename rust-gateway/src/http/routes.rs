use super::handlers::{create_handshake_handler, process_handshake_message_handler, health_handler, metrics_handler, AppState};
use crate::proxy::{proxy_handler, ProxyClient, ProxyState};
use crate::session::SessionStore;
use crate::websocket::{handle_websocket, WebSocketState};
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
    let proxy_client = ProxyClient::new(backend_url.clone(), Duration::from_secs(30));

    // Create proxy state
    let proxy_state = Arc::new(ProxyState {
        session_store: session_store.clone(),
        proxy_client,
    });

    // Create WebSocket state
    // Phoenix WebSocket URL format: ws://localhost:4000/socket/websocket
    let backend_ws_url = backend_url.replace("http://", "ws://").replace("https://", "wss://") + "/socket/websocket";
    let ws_state = Arc::new(WebSocketState {
        session_store,
        backend_url: backend_ws_url,
    });

    Router::new()
        // Noise-specific endpoints (handle internally)
        .route("/noise/handshake", post(create_handshake_handler))
        .route("/noise/handshake/:id/message", post(process_handshake_message_handler))
        .with_state(noise_state)
        // WebSocket endpoint (NOISE encrypted)
        .route("/socket/websocket", get(handle_websocket))
        .with_state(ws_state)
        // Gateway-specific endpoints
        .route("/gateway/health", get(health_handler))
        .route("/gateway/metrics", get(metrics_handler))
        // Reverse proxy for ALL other routes
        // This catches /api/*, /health, etc and forwards to Elixir
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
