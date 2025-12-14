# Rust Noise Gateway

Høy-ytelse Noise Protocol gateway for å offloade tung kryptografi fra Elixir/OTP backend.

## Oversikt

Rust Gateway håndterer alle Noise Protocol handshakes og session management, og kommuniserer med Elixir backend via gRPC (over Unix Domain Sockets eller mTLS).

### Arkitektur

```
Flutter Client → HTTPS → Rust Gateway → gRPC/UDS → Elixir Backend
                    ↓
              Noise Protocol
              Session Store
```

## Funksjoner

- ✅ **Noise Protocol NKpsk0** - Server-autentisering
- ✅ **Noise Protocol XXpsk3** - Mutual authentication
- ✅ **HTTP REST API** - Handshake endpoint for klienter
- ✅ **gRPC Server** - Kommunikasjon med Elixir backend
- ✅ **Unix Domain Sockets** - Lokal høy-ytelse IPC
- ✅ **mTLS Support** - Produksjonsklar sikkerhet
- ✅ **Session Store** - In-memory med TTL
- ✅ **Prometheus Metrics** - Observability
- ✅ **Structured Logging** - JSON logging

## Kom i gang

### Forutsetninger

- Rust 1.75+ (eller nyere)
- OpenSSL (for TLS)

### Bygg

```bash
cargo build --release
```

### Kjør

```bash
# Development (Unix socket)
cargo run

# Production (mTLS)
TRANSPORT_MODE=mtls \
TLS_CERT=./certs/server.pem \
TLS_KEY=./certs/server-key.pem \
TLS_CA=./certs/ca.pem \
cargo run --release
```

### Konfigurasjon

Konfigureres via environment variables eller `config.toml`:

```toml
[server]
http_port = 8443
grpc_port = 50051
server_static_key = "base64-encoded-key"

[transport]
mode = "uds"  # eller "mtls"
socket_path = "/var/run/noise-gateway/noise.sock"

[session]
default_ttl_seconds = 300
cleanup_interval_seconds = 60

[logging]
level = "info"
format = "json"
```

## API Endpoints

### HTTP REST API (for klienter)

```
POST /noise/handshake
Content-Type: application/json

{
  "pattern": "NKpsk0",
  "server_public_key": "base64...",
  "psk": "base64..."
}

→ Response:
{
  "session_id": "uuid",
  "session_token": "base64...",
  "handshake_message": "base64...",
  "signature": "base64...",
  "device_key": "base64...",
  "expires_at": "2024-10-28T12:00:00Z"
}
```

```
GET /health
→ 200 OK
```

```
GET /metrics
→ Prometheus metrics
```

### gRPC API (for Elixir backend)

Se `proto/noise/v1/gateway.proto` for full spesifikasjon.

## Deployment

### Docker

```bash
docker build -t noise-gateway .
docker run -p 8443:8443 -p 50051:50051 noise-gateway
```

### Docker Compose

```yaml
version: '3.8'
services:
  rust-gateway:
    build: ./rust-gateway
    ports:
      - "8443:8443"
      - "50051:50051"
    environment:
      - RUST_LOG=info
      - TRANSPORT_MODE=uds
      - SOCKET_PATH=/var/run/noise-gateway/noise.sock
    volumes:
      - /var/run/noise-gateway:/var/run/noise-gateway
```

## Testing

```bash
# Unit tests
cargo test

# Integration tests
cargo test --test '*'

# Benchmark
cargo bench
```

## Monitoring

### Metrics

Prometheus metrics eksponeres på `/metrics`:

- `noise_gateway_active_sessions` - Antall aktive sessions
- `noise_gateway_handshakes_total` - Totalt antall handshakes
- `noise_gateway_handshakes_failed_total` - Feilede handshakes
- `noise_gateway_request_duration_seconds` - Request latency histogram

### Logging

Structured JSON logging til stdout:

```json
{
  "timestamp": "2024-10-28T12:00:00Z",
  "level": "INFO",
  "target": "noise_gateway::handshake",
  "message": "Handshake created",
  "session_id": "uuid",
  "pattern": "NKpsk0"
}
```

## Sikkerhet

- All kryptografi håndteres av `snow` library (audited Noise implementation)
- TLS 1.3 for transport-layer security
- Constant-time comparisons for token verification
- Session TTL med automatic cleanup
- Rate limiting på handshake endpoints

## Ytelse

Forventet throughput på moderne CPU:

- **Handshakes**: 10,000+ per sekund
- **Session lookups**: 1,000,000+ per sekund
- **Encrypt/Decrypt**: 500,000+ operasjoner per sekund

Memory usage:

- **Base**: ~10 MB
- **Per session**: ~2 KB
- **1M sessions**: ~2 GB

## Bidra

Se [CONTRIBUTING.md](../docs/CONTRIBUTING.md) for retningslinjer.

## Lisens

MIT OR Apache-2.0
