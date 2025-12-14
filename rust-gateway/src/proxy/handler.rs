use crate::error::Result;
use crate::proxy::ProxyClient;
use crate::session::SessionStore;
use axum::{
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, HeaderName, HeaderValue},
    response::Response,
};
use std::sync::Arc;
use tracing::{debug, error, info};

/// Application state for proxy
#[derive(Clone)]
pub struct ProxyState {
    pub session_store: SessionStore,
    pub proxy_client: ProxyClient,
}

/// Proxy handler - forwards requests to Elixir backend
pub async fn proxy_handler(
    State(state): State<Arc<ProxyState>>,
    request: Request,
) -> Result<Response> {
    let method = request.method().clone();
    let uri = request.uri().clone();
    let path = uri.path();

    debug!(
        method = %method,
        path = %path,
        "Proxying request to backend"
    );

    // Extract Noise session token from Authorization header
    let noise_token = extract_noise_token(request.headers());

    // Verify token and get session context (if present)
    let session_context = if let Some(token) = noise_token {
        match state.session_store.verify_token(&token) {
            Ok((session_id, metadata, _ttl)) => {
                info!(
                    session_id = %session_id,
                    account_id = ?metadata.account_id,
                    "Request authenticated via Noise session"
                );

                Some(SessionContext {
                    session_id: session_id.to_string(),
                    account_id: metadata.account_id,
                    profile_id: metadata.profile_id,
                    device_id: metadata.device_id,
                })
            }
            Err(e) => {
                debug!(error = %e, "Token verification failed");
                None
            }
        }
    } else {
        None
    };

    // Build backend URL
    let backend_url = state
        .proxy_client
        .build_url(path)
        .map_err(|e| crate::error::GatewayError::Http(format!("Invalid URL: {}", e)))?;

    // Build request to backend
    let mut backend_request = state
        .proxy_client
        .client()
        .request(method.clone(), backend_url);

    // Copy headers from original request (except Host and Authorization)
    for (name, value) in request.headers().iter() {
        if name != "host" && name != "authorization" {
            backend_request = backend_request.header(name, value);
        }
    }

    // Inject session context as headers
    if let Some(ctx) = &session_context {
        backend_request = backend_request.header("X-Session-Id", &ctx.session_id);

        if let Some(ref account_id) = ctx.account_id {
            backend_request = backend_request.header("X-Account-Id", account_id);
        }

        if let Some(ref profile_id) = ctx.profile_id {
            backend_request = backend_request.header("X-Profile-Id", profile_id);
        }

        if let Some(ref device_id) = ctx.device_id {
            backend_request = backend_request.header("X-Device-Id", device_id);
        }
    }

    // Get request body
    let body_bytes = axum::body::to_bytes(request.into_body(), usize::MAX)
        .await
        .map_err(|e| crate::error::GatewayError::Http(format!("Failed to read body: {}", e)))?;

    // Send request to backend
    let backend_response = backend_request
        .body(body_bytes.to_vec())
        .send()
        .await
        .map_err(|e| {
            error!(error = %e, "Failed to proxy request to backend");
            crate::error::GatewayError::Http(format!("Backend request failed: {}", e))
        })?;

    // Build response
    let status = backend_response.status();
    let mut response_headers = HeaderMap::new();

    // Copy response headers
    for (name, value) in backend_response.headers().iter() {
        if let Ok(header_name) = HeaderName::try_from(name.as_str()) {
            if let Ok(header_value) = HeaderValue::try_from(value.as_bytes()) {
                response_headers.insert(header_name, header_value);
            }
        }
    }

    // Get response body
    let response_body = backend_response
        .bytes()
        .await
        .map_err(|e| crate::error::GatewayError::Http(format!("Failed to read response: {}", e)))?;

    // Build final response
    let mut response = Response::builder()
        .status(status)
        .body(Body::from(response_body.to_vec()))
        .unwrap();

    *response.headers_mut() = response_headers;

    Ok(response)
}

/// Extract Noise token from Authorization header
fn extract_noise_token(headers: &HeaderMap) -> Option<String> {
    let auth_header = headers.get("authorization")?.to_str().ok()?;

    // Check for "Noise <token>" format
    if auth_header.starts_with("Noise ") {
        Some(auth_header.trim_start_matches("Noise ").to_string())
    } else if auth_header.starts_with("Bearer ") {
        // Also support Bearer for compatibility
        Some(auth_header.trim_start_matches("Bearer ").to_string())
    } else {
        None
    }
}

/// Session context extracted from Noise token
#[derive(Debug, Clone)]
struct SessionContext {
    session_id: String,
    account_id: Option<String>,
    profile_id: Option<String>,
    device_id: Option<String>,
}
