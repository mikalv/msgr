use reqwest::{Client, Url};
use std::time::Duration;

/// HTTP client for proxying requests to Elixir backend
#[derive(Clone)]
pub struct ProxyClient {
    client: Client,
    backend_url: String,
}

impl ProxyClient {
    /// Create new proxy client
    pub fn new(backend_url: String, timeout: Duration) -> Self {
        let client = Client::builder()
            .timeout(timeout)
            .pool_max_idle_per_host(100)
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            backend_url,
        }
    }

    /// Build URL for backend
    pub fn build_url(&self, path: &str) -> Result<Url, url::ParseError> {
        let base = Url::parse(&self.backend_url)?;
        base.join(path)
    }

    /// Get reqwest client
    pub fn client(&self) -> &Client {
        &self.client
    }

    /// Backend base URL
    pub fn backend_url(&self) -> &str {
        &self.backend_url
    }
}
