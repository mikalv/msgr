# Noise Gateway Integration Tests

Full end-to-end integration tests for the Noise Gateway architecture.

## Architecture

```
Flutter Client (Dart)
        ↓ Noise Protocol / HTTP
    Rust Gateway (:8443)
        ↓ HTTP Proxy + gRPC
    Elixir Backend (:4000)
        ↓ PostgreSQL
```

## Prerequisites

### 1. Start PostgreSQL
```bash
# Make sure PostgreSQL is running with the msgr database
psql -U postgres -c "CREATE DATABASE msgr_dev;"
```

### 2. Start Elixir Backend
```bash
cd /Users/mikalv/Repos/Kommunikasjon/chat/backend
mix deps.get
mix ecto.create
mix ecto.migrate
iex -S mix phx.server
```

The Elixir backend will:
- Listen on `http://localhost:4000` (HTTP API - localhost only)
- Listen on `http://localhost:50052` (gRPC server for Rust)

### 3. Start Rust Gateway
```bash
cd /Users/mikalv/Repos/Kommunikasjon/chat/rust-gateway

# Set environment variables
export BACKEND_URL=http://localhost:4000
export ELIXIR_GRPC_URL=http://localhost:50052
export SERVER_STATIC_KEY=your_32_byte_hex_key_here

# Run gateway
cargo run
```

The Rust Gateway will:
- Listen on `http://0.0.0.0:8443` (HTTP API + Noise)
- Listen on `http://0.0.0.0:50051` (gRPC server for Elixir)
- Proxy HTTP requests to Elixir backend
- Handle Noise protocol crypto

## Running Tests

### Interactive Mode (Recommended)

Open two terminals and run a client in each:

**Terminal 1 - Alice:**
```bash
cd /Users/mikalv/Repos/Kommunikasjon/chat/flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --alice
```

**Terminal 2 - Bob:**
```bash
cd /Users/mikalv/Repos/Kommunikasjon/chat/flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --bob
```

### Automated Mode

For CI/CD environments (limited to handshake testing):

```bash
dart test/integration/noise_gateway_test.dart
```

## Test Flow

1. **Noise Handshake**
   - Client → Rust Gateway: POST `/noise/handshake`
   - Rust performs Noise Protocol handshake
   - Rust → Elixir gRPC: `ValidateDevice(device_public_key)`
   - Returns `session_id` and `session_token`

2. **OTP Challenge**
   - Client → Rust Gateway: POST `/api/auth/challenge`
   - Rust proxies to Elixir with session headers
   - Elixir sends OTP via email
   - Returns `challenge_id`

3. **OTP Verification**
   - Client → Rust Gateway: POST `/api/auth/verify`
   - Client includes `session_id` and `session_token`
   - Elixir verifies OTP
   - Elixir → Rust gRPC: `BindAccount(session_id, account_id, profile_id)`
   - Rust updates in-memory session store
   - Returns account/profile info

4. **Send Message**
   - Client → Rust Gateway: POST `/api/messages`
   - Rust injects session context headers
   - Elixir receives with X-Account-Id, X-Profile-Id headers
   - Message routed through Phoenix Channels to recipient

## Environment Variables

### Rust Gateway

```bash
# .env file or export
SERVER_STATIC_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
HTTP_PORT=8443
GRPC_PORT=50051
BACKEND_URL=http://localhost:4000
ELIXIR_GRPC_URL=http://localhost:50052
SESSION_MAX_SESSIONS=10000
SESSION_DEFAULT_TTL_SECONDS=3600
SESSION_CLEANUP_INTERVAL_SECONDS=300
LOG_LEVEL=info
LOG_FORMAT=pretty
```

### Elixir Backend

```bash
# config/runtime.exs reads these
DATABASE_URL=postgresql://postgres:postgres@localhost/msgr_dev
PORT=4000
SECRET_KEY_BASE=your_secret_key_base_here
RUST_GATEWAY_HOST=localhost
RUST_GATEWAY_GRPC_PORT=50051
RUST_GATEWAY_SERVER_PORT=50052
```

## Debugging

### Check Rust Gateway Logs
```bash
# In rust-gateway directory
RUST_LOG=debug cargo run
```

### Check Elixir Logs
```bash
# In backend directory
LOG_LEVEL=debug iex -S mix phx.server
```

### Test Individual Components

**Test Rust Gateway directly:**
```bash
curl -X POST http://localhost:8443/noise/handshake \
  -H "Content-Type: application/json" \
  -d '{"pattern": "NKpsk0"}'
```

**Test Elixir Backend (through Rust proxy):**
```bash
curl http://localhost:8443/api/health
```

**Test gRPC (Rust → Elixir):**
```bash
# Install grpcurl
# brew install grpcurl

grpcurl -plaintext \
  -d '{"device_public_key": "test123"}' \
  localhost:50052 \
  noise.v1.NoiseBackend/ValidateDevice
```

## Common Issues

### "Connection refused" on port 8443
- Make sure Rust Gateway is running: `cargo run` in rust-gateway directory
- Check firewall settings

### "Connection refused" on port 4000
- Make sure Elixir backend is running: `iex -S mix phx.server`
- Check that Elixir binds to localhost:4000

### "Device not found" during Noise handshake
- The device public key needs to exist in Elixir's PostgreSQL database
- For testing, Elixir's gRPC server might be configured to allow unknown devices
- Check `ELIXIR_GRPC_URL` environment variable in Rust

### "Invalid OTP code"
- Check your email for the code
- OTP codes expire after 5 minutes
- Make sure clock is synchronized

## Architecture Notes

### Session Flow

1. **Noise Handshake Creates Anonymous Session**
   - Rust generates UUID session_id
   - Stores in-memory with device info
   - Returns session_token (JWT-like)

2. **OTP Verification Links Session to Account**
   - Elixir calls `BindAccount` gRPC on Rust
   - Rust updates session with account_id, profile_id
   - Session now authenticated

3. **Subsequent Requests Use Session Token**
   - Client sends X-Noise-Token header
   - Rust verifies token → extracts session_id
   - Rust injects X-Account-Id, X-Profile-Id headers
   - Elixir receives authenticated request

### Why Rust + Elixir?

- **Rust**: Fast Noise crypto, doesn't block BEAM VM
- **Elixir**: Business logic, Phoenix Channels, PostgreSQL
- **gRPC**: Bidirectional communication for device validation and account binding
- **HTTP Proxy**: Rust transparently forwards to Elixir, adds session context
