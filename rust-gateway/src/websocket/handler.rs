use crate::error::{NoiseError, Result};
use crate::noise::handshake;
use crate::session::SessionStore;
use axum::{
    extract::{
        ws::{Message as AxumMessage, WebSocket, WebSocketUpgrade},
        State,
    },
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
};
use futures_util::{SinkExt, StreamExt};
use std::sync::Arc;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message as TungsteniteMessage};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

/// Shared state for WebSocket handler
#[derive(Clone)]
pub struct WebSocketState {
    pub session_store: SessionStore,
    pub backend_url: String,
}

/// Handle WebSocket upgrade request
pub async fn handle_websocket(
    ws: WebSocketUpgrade,
    State(state): State<Arc<WebSocketState>>,
    headers: HeaderMap,
) -> impl IntoResponse {
    // Extract Authorization header
    let auth_header = match headers.get(header::AUTHORIZATION) {
        Some(h) => h,
        None => {
            warn!("WebSocket upgrade missing Authorization header");
            return (
                StatusCode::UNAUTHORIZED,
                "Missing Authorization header",
            )
                .into_response();
        }
    };

    // Parse Bearer token
    let auth_str = match auth_header.to_str() {
        Ok(s) => s,
        Err(_) => {
            warn!("Invalid Authorization header encoding");
            return (StatusCode::UNAUTHORIZED, "Invalid Authorization header").into_response();
        }
    };

    let token = match auth_str.strip_prefix("Bearer ") {
        Some(t) => t,
        None => {
            warn!("Authorization header not in Bearer format");
            return (
                StatusCode::UNAUTHORIZED,
                "Authorization must be Bearer token",
            )
                .into_response();
        }
    };

    // Verify token and get session
    let session_id = match state.session_store.get_session_by_token(token) {
        Ok(id) => id,
        Err(e) => {
            warn!("Invalid or expired session token: {}", e);
            return (StatusCode::UNAUTHORIZED, "Invalid or expired token").into_response();
        }
    };

    info!(
        session_id = %session_id,
        "WebSocket upgrade authorized"
    );

    // Upgrade to WebSocket
    ws.on_upgrade(move |socket| handle_socket(socket, state, session_id))
        .into_response()
}

/// Handle WebSocket connection
async fn handle_socket(client_ws: WebSocket, state: Arc<WebSocketState>, session_id: Uuid) {
    info!(session_id = %session_id, "WebSocket connection established");

    // Connect to Phoenix backend
    let backend_ws = match connect_to_backend(&state.backend_url).await {
        Ok(ws) => ws,
        Err(e) => {
            error!(
                session_id = %session_id,
                error = %e,
                "Failed to connect to backend"
            );
            let _ = client_ws
                .close()
                .await;
            return;
        }
    };

    info!(
        session_id = %session_id,
        backend_url = %state.backend_url,
        "Connected to Phoenix backend"
    );

    // Split WebSockets for bidirectional communication
    let (mut client_sink, mut client_stream) = client_ws.split();
    let (mut backend_sink, mut backend_stream) = backend_ws.split();

    // Clone session store for both tasks
    let store_client_to_backend = state.session_store.clone();
    let store_backend_to_client = state.session_store.clone();

    // Spawn task for client → backend (decrypt)
    let session_id_c2b = session_id;
    let client_to_backend = tokio::spawn(async move {
        while let Some(msg) = client_stream.next().await {
            match msg {
                Ok(AxumMessage::Binary(encrypted)) => {
                    debug!(
                        session_id = %session_id_c2b,
                        size = encrypted.len(),
                        "Received encrypted message from client"
                    );

                    // Decrypt with NOISE
                    let plaintext = match handshake::decrypt(&store_client_to_backend, &session_id_c2b, &encrypted).await {
                        Ok(p) => p,
                        Err(e) => {
                            error!(
                                session_id = %session_id_c2b,
                                error = %e,
                                "Failed to decrypt message from client"
                            );
                            break;
                        }
                    };

                    debug!(
                        session_id = %session_id_c2b,
                        plaintext_size = plaintext.len(),
                        "Decrypted message, forwarding to backend"
                    );

                    // Forward plaintext to Phoenix
                    if let Err(e) = backend_sink.send(TungsteniteMessage::Binary(plaintext)).await {
                        error!(
                            session_id = %session_id_c2b,
                            error = %e,
                            "Failed to send to backend"
                        );
                        break;
                    }
                }
                Ok(AxumMessage::Text(text)) => {
                    warn!(
                        session_id = %session_id_c2b,
                        "Received unexpected text message from client: {}",
                        text
                    );
                }
                Ok(AxumMessage::Close(_)) => {
                    info!(session_id = %session_id_c2b, "Client closed connection");
                    break;
                }
                Ok(AxumMessage::Ping(data)) => {
                    // Forward ping to backend
                    let _ = backend_sink.send(TungsteniteMessage::Ping(data)).await;
                }
                Ok(AxumMessage::Pong(_)) => {
                    // Ignore pongs
                }
                Err(e) => {
                    error!(
                        session_id = %session_id_c2b,
                        error = %e,
                        "WebSocket error from client"
                    );
                    break;
                }
            }
        }

        debug!(session_id = %session_id_c2b, "Client → Backend task finished");
    });

    // Spawn task for backend → client (encrypt)
    let session_id_b2c = session_id;
    let backend_to_client = tokio::spawn(async move {
        while let Some(msg) = backend_stream.next().await {
            match msg {
                Ok(TungsteniteMessage::Binary(plaintext)) => {
                    debug!(
                        session_id = %session_id_b2c,
                        size = plaintext.len(),
                        "Received message from backend"
                    );

                    // Encrypt with NOISE
                    let encrypted = match handshake::encrypt(&store_backend_to_client, &session_id_b2c, &plaintext).await {
                        Ok(e) => e,
                        Err(e) => {
                            error!(
                                session_id = %session_id_b2c,
                                error = %e,
                                "Failed to encrypt message from backend"
                            );
                            break;
                        }
                    };

                    debug!(
                        session_id = %session_id_b2c,
                        encrypted_size = encrypted.len(),
                        "Encrypted message, forwarding to client"
                    );

                    // Forward encrypted to client
                    if let Err(e) = client_sink.send(AxumMessage::Binary(encrypted)).await {
                        error!(
                            session_id = %session_id_b2c,
                            error = %e,
                            "Failed to send to client"
                        );
                        break;
                    }
                }
                Ok(TungsteniteMessage::Text(text)) => {
                    debug!(
                        session_id = %session_id_b2c,
                        size = text.len(),
                        "Received text message from backend"
                    );

                    // Phoenix channels use text messages, encrypt them
                    let encrypted = match handshake::encrypt(&store_backend_to_client, &session_id_b2c, text.as_bytes()).await {
                        Ok(e) => e,
                        Err(e) => {
                            error!(
                                session_id = %session_id_b2c,
                                error = %e,
                                "Failed to encrypt text message from backend"
                            );
                            break;
                        }
                    };

                    // Send as binary (NOISE encrypted)
                    if let Err(e) = client_sink.send(AxumMessage::Binary(encrypted)).await {
                        error!(
                            session_id = %session_id_b2c,
                            error = %e,
                            "Failed to send to client"
                        );
                        break;
                    }
                }
                Ok(TungsteniteMessage::Close(_)) => {
                    info!(session_id = %session_id_b2c, "Backend closed connection");
                    break;
                }
                Ok(TungsteniteMessage::Ping(data)) => {
                    // Forward ping to client
                    let _ = client_sink.send(AxumMessage::Ping(data)).await;
                }
                Ok(TungsteniteMessage::Pong(_)) => {
                    // Ignore pongs
                }
                Err(e) => {
                    error!(
                        session_id = %session_id_b2c,
                        error = %e,
                        "WebSocket error from backend"
                    );
                    break;
                }
                Ok(TungsteniteMessage::Frame(_)) => {
                    // Ignore raw frames
                }
            }
        }

        debug!(session_id = %session_id_b2c, "Backend → Client task finished");
    });

    // Wait for both tasks to complete
    let _ = tokio::join!(client_to_backend, backend_to_client);

    info!(session_id = %session_id, "WebSocket connection closed");
}

/// Connect to Phoenix backend WebSocket
async fn connect_to_backend(
    backend_url: &str,
) -> Result<tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>>
{
    let (ws_stream, _) = connect_async(backend_url)
        .await
        .map_err(|e| NoiseError::Internal(format!("Backend connection failed: {}", e)))?;

    Ok(ws_stream)
}
