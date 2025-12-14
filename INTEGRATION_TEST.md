# Noise Gateway Integration Testing

Full end-to-end integration testing for the new Rust Gateway architecture.

## Quick Start

```bash
# 1. Start all services
./start-integration-test.sh

# 2. In another terminal, run Alice
cd flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --alice

# 3. In a third terminal, run Bob
cd flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --bob

# 4. Alice and Bob can now send messages to each other!
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                                                               │
│  Integration Test: 2 CLI Clients Sending Messages            │
│                                                               │
│  ┌──────────┐                              ┌──────────┐     │
│  │  Alice   │                              │   Bob    │     │
│  │  (Dart)  │                              │  (Dart)  │     │
│  └────┬─────┘                              └────┬─────┘     │
│       │                                          │           │
│       │ Noise Protocol                           │           │
│       │ HTTP/JSON                                │           │
│       │                                          │           │
│       ▼                                          ▼           │
│  ┌────────────────────────────────────────────────────┐     │
│  │          Rust Gateway (:8443)                      │     │
│  │                                                     │     │
│  │  ┌─────────────────────────────────────┐          │     │
│  │  │  Noise Protocol Handler              │          │     │
│  │  │  - Handshake (NKpsk0/XXpsk3/IKpsk2) │          │     │
│  │  │  - Session management (in-memory)    │          │     │
│  │  │  - Device validation via gRPC        │          │     │
│  │  └─────────────────────────────────────┘          │     │
│  │                                                     │     │
│  │  ┌─────────────────────────────────────┐          │     │
│  │  │  HTTP Reverse Proxy                  │          │     │
│  │  │  - Transparent proxy to Elixir       │          │     │
│  │  │  - Session context injection         │          │     │
│  │  │  - Headers: X-Account-Id, X-Profile  │          │     │
│  │  └─────────────────────────────────────┘          │     │
│  │                                                     │     │
│  │  gRPC Server :50051  │  gRPC Client                │     │
│  │  ← BindAccount       │  → ValidateDevice :50052    │     │
│  └─────────┬────────────────────────────┬────────────┘     │
│            │                             │                   │
│            │ HTTP Proxy                  │ gRPC              │
│            │                             │                   │
│       ▼────┴─────────────────────────────┴─────▼           │
│  ┌───────────────────────────────────────────────────┐     │
│  │         Elixir Backend (:4000)                     │     │
│  │                                                     │     │
│  │  ┌─────────────────────────────────────┐          │     │
│  │  │  Phoenix Framework                   │          │     │
│  │  │  - HTTP API (localhost only)         │          │     │
│  │  │  - Auth (challenge/verify)           │          │     │
│  │  │  - Business logic                    │          │     │
│  │  └─────────────────────────────────────┘          │     │
│  │                                                     │     │
│  │  ┌─────────────────────────────────────┐          │     │
│  │  │  gRPC Server (:50052)                │          │     │
│  │  │  - ValidateDevice                    │          │     │
│  │  │  - Returns device_id, account_id     │          │     │
│  │  └─────────────────────────────────────┘          │     │
│  │                                                     │     │
│  │  ┌─────────────────────────────────────┐          │     │
│  │  │  Phoenix Channels (WebSocket)        │          │     │
│  │  │  - Real-time message routing         │          │     │
│  │  │  - Presence tracking                 │          │     │
│  │  └─────────────────────────────────────┘          │     │
│  │                                                     │     │
│  └──────────────────┬──────────────────────────────┘     │
│                      │                                     │
│                      ▼                                     │
│              ┌─────────────┐                              │
│              │ PostgreSQL  │                              │
│              │  :5432      │                              │
│              └─────────────┘                              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Test Flow

### Phase 1: Noise Handshake (Anonymous Session)

```
Alice → Rust Gateway: POST /noise/handshake
                      {pattern: "NKpsk0"}

Rust Gateway:
  1. Creates Noise handshake state
  2. Generates UUID session_id
  3. Calls Elixir gRPC: ValidateDevice(device_public_key)
  4. Stores session in-memory (DashMap)
  5. Returns session_id + session_token

Alice ← {session_id, token}
```

### Phase 2: OTP Challenge

```
Alice → Rust Gateway: POST /api/auth/challenge
                      Header: X-Noise-Token
                      {channel: "email", identifier: "alice@example.com"}

Rust Gateway:
  1. Verifies session token
  2. Proxies to Elixir with headers:
     - X-Session-Id
     - X-Account-Id (null at this point)

Elixir:
  1. Creates OTP challenge
  2. Sends email with code
  3. Returns challenge_id

Alice ← {id: "challenge-uuid"}
```

### Phase 3: OTP Verification (Session Binding)

```
Alice → Rust Gateway: POST /api/auth/verify
                      Header: X-Noise-Token
                      {
                        challenge_id: "uuid",
                        code: "123456",
                        session_id: "session-uuid",
                        session_token: "token"
                      }

Rust Gateway:
  1. Proxies to Elixir

Elixir:
  1. Verifies OTP code
  2. Creates/finds account
  3. Calls Rust gRPC: BindAccount(
       session_id,
       session_token,
       account_id,
       profile_id,
       device_id
     )

Rust Gateway:
  1. Updates in-memory session
  2. Links session_id → account_id, profile_id

Elixir → Alice: {account: {...}, profile: {...}}
```

### Phase 4: Send Message (Authenticated)

```
Alice → Rust Gateway: POST /api/messages
                      Header: X-Noise-Token
                      {
                        to_profile_id: "bob-profile-id",
                        content: "Hello Bob!",
                        type: "text"
                      }

Rust Gateway:
  1. Verifies token → gets session
  2. Adds headers:
     - X-Account-Id: alice-account-id
     - X-Profile-Id: alice-profile-id
  3. Proxies to Elixir

Elixir:
  1. Receives authenticated request
  2. Creates message in PostgreSQL
  3. Routes via Phoenix Channels to Bob

Bob ← Phoenix Channel: new:msg {content: "Hello Bob!"}
```

## Manual Testing Steps

### 1. Start Services

```bash
# Start all at once
./start-integration-test.sh

# Or start individually:

# Terminal 1: PostgreSQL (if not running)
brew services start postgresql@14

# Terminal 2: Elixir
cd backend
iex -S mix phx.server

# Terminal 3: Rust
cd rust-gateway
cargo run
```

### 2. Run Alice Client

```bash
cd flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --alice

# Follow prompts:
# 1. Creates Noise handshake
# 2. Enter email: alice@example.com
# 3. Enter OTP code from email
# 4. Send messages to Bob's profile ID
```

### 3. Run Bob Client

```bash
cd flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --bob

# Follow prompts:
# 1. Creates Noise handshake
# 2. Enter email: bob@example.com
# 3. Enter OTP code from email
# 4. Send messages to Alice's profile ID
```

## Verification Checklist

- [ ] Rust Gateway starts without errors
- [ ] Elixir Backend starts without errors
- [ ] gRPC servers are listening (:50051, :50052)
- [ ] Alice creates Noise handshake successfully
- [ ] Bob creates Noise handshake successfully
- [ ] Alice receives OTP email
- [ ] Bob receives OTP email
- [ ] Alice OTP verification succeeds
- [ ] Bob OTP verification succeeds
- [ ] Session bound to account in Rust
- [ ] Alice can send message to Bob
- [ ] Bob receives message from Alice
- [ ] Bob can send message to Alice
- [ ] Alice receives message from Bob

## Debugging Tips

### Check Rust Logs

```bash
cd rust-gateway
RUST_LOG=debug cargo run
```

Look for:
- `[+] Noise handshake created`
- `[gRPC] Calling Elixir ValidateDevice`
- `[Proxy] Injecting session headers`

### Check Elixir Logs

```bash
cd backend
LOG_LEVEL=debug iex -S mix phx.server
```

Look for:
- `[gRPC] Received ValidateDevice request`
- `[Auth] Challenge created`
- `[Auth] OTP verified, binding session`
- `[gRPC] Calling Rust BindAccount`

### Check gRPC Communication

```bash
# Install grpcurl
brew install grpcurl

# Test Elixir gRPC (ValidateDevice)
grpcurl -plaintext \
  -d '{"device_public_key": "test_key"}' \
  localhost:50052 \
  noise.v1.NoiseBackend/ValidateDevice

# Test Rust gRPC (BindAccount)
grpcurl -plaintext \
  -d '{
    "session_id": "uuid",
    "session_token": "token",
    "account_id": "account-uuid",
    "profile_id": "profile-uuid"
  }' \
  localhost:50051 \
  noise.v1.NoiseBackend/BindAccount
```

### Check HTTP Endpoints

```bash
# Rust Gateway health
curl http://localhost:8443/gateway/health

# Elixir health (via Rust proxy)
curl http://localhost:8443/api/health

# Noise handshake
curl -X POST http://localhost:8443/noise/handshake \
  -H "Content-Type: application/json" \
  -d '{"pattern": "NKpsk0"}'
```

## Common Issues

### "Connection refused" on port 8443
- Rust Gateway not running
- Check: `lsof -i :8443`
- Fix: `cd rust-gateway && cargo run`

### "Connection refused" on port 4000
- Elixir not running
- Check: `lsof -i :4000`
- Fix: `cd backend && iex -S mix phx.server`

### "gRPC connection failed"
- Elixir gRPC not started
- Check: `lsof -i :50052`
- Check Elixir logs for gRPC server startup

### "Device not found"
- Device public key not in database
- For testing, Elixir may be configured to allow unknown devices
- Check `validate_device/2` in `rust_gateway/server.ex`

### "Invalid OTP"
- OTP expired (5 min timeout)
- Wrong code entered
- Check email spam folder

## Performance Notes

- Rust Gateway can handle ~100k sessions in memory
- Session cleanup runs every 5 minutes
- Default session TTL: 1 hour
- Handshake timeout: 30 seconds
- OTP timeout: 5 minutes

## Security Notes

- Rust Gateway uses Noise Protocol for E2E crypto
- Session tokens are cryptographically signed
- gRPC between Rust and Elixir uses localhost (no TLS needed)
- HTTP proxy only accepts from localhost
- Sessions expire automatically

## Next Steps

After successful integration test:

1. **WebSocket Support**: Add WebSocket proxying in Rust
2. **Production Keys**: Generate proper Noise static keys
3. **Metrics**: Add Prometheus metrics
4. **Rate Limiting**: Implement per-session rate limits
5. **Logging**: Structured logging with correlation IDs
6. **Docker Compose**: Containerize all services
7. **CI/CD**: Automated integration tests

## Files Created

```
chat/
├── start-integration-test.sh              # Start all services
├── INTEGRATION_TEST.md                     # This file
├── rust-gateway/
│   ├── .env                                # Rust config (created)
│   └── ...
└── flutter_frontend/packages/libmsgr/
    └── test/integration/
        ├── noise_gateway_test.dart         # CLI test clients
        └── README.md                        # Detailed test docs
```

## Contact

For issues or questions about the integration tests:
- Check logs in Rust and Elixir
- Verify all services are running
- Ensure PostgreSQL database is up
- Check firewall/network settings
