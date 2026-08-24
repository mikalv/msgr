# Rust Gateway as HTTP Proxy

## Ny Arkitektur

Rust Gateway fungerer som **edge proxy** foran Elixir backend:

```
┌─────────────────────────────────────────────────────────────┐
│                  Flutter Client                              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                    HTTPS (port 8443)
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Rust Gateway (Edge Proxy)                       │
│  ┌──────────────────────────────────────────────┐           │
│  │  HTTP Server (Axum)                          │           │
│  │  • Port 8443 (external)                      │           │
│  │  • TLS termination                           │           │
│  └────────────────┬─────────────────────────────┘           │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────┐           │
│  │  Request Router                              │           │
│  │  • /noise/handshake → Noise handler          │           │
│  │  • /api/* → Proxy til Elixir                 │           │
│  │  • /socket → WebSocket proxy                 │           │
│  └────────────────┬─────────────────────────────┘           │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────┐           │
│  │  Noise Protocol Service                      │           │
│  │  • Handshake handling                        │           │
│  │  • Session management                        │           │
│  │  • Token validation                          │           │
│  └──────────────────────────────────────────────┘           │
│                                                              │
│  ┌──────────────────────────────────────────────┐           │
│  │  HTTP Proxy (tower-http)                     │           │
│  │  • Forward requests to Elixir                │           │
│  │  • Inject session context                    │           │
│  │  • Connection pooling                        │           │
│  └────────────────┬─────────────────────────────┘           │
└───────────────────┼─────────────────────────────────────────┘
                    │
          HTTP (internal, port 4000)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              Elixir Backend (Phoenix)                        │
│  ┌──────────────────────────────────────────────┐           │
│  │  Phoenix Endpoint                            │           │
│  │  • Listens on localhost:4000                 │           │
│  │  • NO external exposure                      │           │
│  │  • NO TLS (proxy handles it)                 │           │
│  └────────────────┬─────────────────────────────┘           │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────┐           │
│  │  Request Plug Pipeline                       │           │
│  │  • Extract session from headers              │           │
│  │  • Load Account/Profile/Device               │           │
│  │  • Business logic                            │           │
│  └────────────────┬─────────────────────────────┘           │
│                   │                                          │
│  ┌────────────────▼─────────────────────────────┐           │
│  │  Controllers & Channels                      │           │
│  │  • NO Noise code                             │           │
│  │  • Standard Phoenix patterns                 │           │
│  │  • Session via headers                       │           │
│  └──────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. Noise Handshake (unchanged)

```
Flutter → POST /noise/handshake → Rust Gateway
       → Noise protocol processing
       → Return {session_id, token, ...}
```

### 2. OTP Verification (proxied)

```
Flutter → POST /api/v1/auth/verify (OTP code, noise_session_id)
       → Rust Gateway
       → Validate noise_session_id exists
       → Proxy to Elixir: http://localhost:4000/api/v1/auth/verify
       → Elixir verifies OTP
       → Rust intercepts response
       → Bind account_id to noise session
       → Return to Flutter
```

### 3. Authenticated Requests (proxied with session)

```
Flutter → POST /api/conversations
          Authorization: Noise <token>
       → Rust Gateway
       → Verify token → get account_id, profile_id
       → Proxy to Elixir with headers:
          X-Account-Id: <account_id>
          X-Profile-Id: <profile_id>
          X-Device-Id: <device_id>
          X-Session-Id: <session_id>
       → Elixir processes request
       → Returns response
       → Rust forwards to Flutter
```

### 4. WebSocket (proxied)

```
Flutter → WSS /socket?noise_session=<token>
       → Rust Gateway
       → Verify token
       → Upgrade to WebSocket
       → Proxy WebSocket to Elixir:
          ws://localhost:4000/socket?account_id=...&profile_id=...
       → Bidirectional proxy
```

## Fordeler med denne arkitekturen

✅ **Separasjon av ansvar**
- Rust: Kryptografi, edge security, TLS
- Elixir: Business logic, chat, database

✅ **Ingen port-konflikter**
- Rust: 8443 (external)
- Elixir: 4000 (internal only)

✅ **Enklere Elixir**
- Fjern all Noise-kode
- Fjern DevHandshake
- Standard Phoenix patterns

✅ **Bedre sikkerhet**
- TLS terminering i Rust
- Noise protocol isolert
- Elixir trenger ikke håndtere crypto

✅ **Skalerbarhet**
- Rust kan load balance til flere Elixir instances
- Session state i Rust (kan Redis-backes)
- Elixir nodes kan være stateless

## Headers Injisert av Rust

Rust proxy injiserer disse headers til Elixir:

```
X-Account-Id: <uuid>
X-Profile-Id: <uuid>
X-Device-Id: <uuid>
X-Session-Id: <uuid>
X-Noise-Session: <token>  # For debugging
X-Forwarded-For: <client-ip>
X-Real-IP: <client-ip>
```

Elixir Plug:

```elixir
defmodule MessngrWeb.Plugs.SessionContext do
  @moduledoc """
  Extract session context from headers injected by Rust Gateway
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:current_account_id, get_req_header(conn, "x-account-id") |> List.first())
    |> assign(:current_profile_id, get_req_header(conn, "x-profile-id") |> List.first())
    |> assign(:current_device_id, get_req_header(conn, "x-device-id") |> List.first())
    |> assign(:session_id, get_req_header(conn, "x-session-id") |> List.first())
  end
end
```

## Konfigurasjon

### Rust Gateway

```toml
[server]
http_port = 8443
grpc_port = 50051  # Kun for admin/internal
server_static_key = "..."

[proxy]
backend_url = "http://localhost:4000"
timeout_seconds = 30
pool_size = 100

[session]
default_ttl_seconds = 300
```

### Elixir Backend

```elixir
# config/config.exs
config :msgr_web, MessngrWeb.Endpoint,
  http: [port: 4000, ip: {127, 0, 0, 1}],  # Localhost only!
  url: [host: "localhost"],
  server: true

# REMOVE:
# - Noise.Handshake
# - Noise.DevHandshake
# - Noise.Session
# - NoiseHandshakeController
# - All Noise-related plugs
```

## Migration Plan

### Fase 1: Rust Proxy Implementation
1. ✅ Implementer HTTP proxy i Rust
2. ✅ Session header injection
3. ✅ WebSocket proxy
4. ✅ Health checks

### Fase 2: Elixir Cleanup
1. Remove Noise modules
2. Remove NoiseHandshakeController
3. Update Plugs (SessionContext)
4. Update tests

### Fase 3: Testing
1. Integration tests
2. Load testing
3. WebSocket stress testing

### Fase 4: Deployment
1. Deploy Rust gateway
2. Deploy updated Elixir backend
3. Update Flutter client (minimal changes)
4. Monitor

## URL Mapping

| Flutter Request | Rust Gateway | Elixir Backend |
|----------------|--------------|----------------|
| POST /noise/handshake | Handle internally | N/A |
| POST /api/v1/auth/challenge | Proxy | POST /api/v1/auth/challenge |
| POST /api/v1/auth/verify | Proxy + bind account | POST /api/v1/auth/verify |
| GET /api/conversations | Proxy + session headers | GET /api/conversations |
| WSS /socket | WebSocket proxy | WSS /socket |
| GET /health | Combine (Rust + Elixir) | GET /health |

## Rollback Plan

Hvis det oppstår problemer:

1. **Revert Elixir**: Restore Noise code (git revert)
2. **Route direkte**: Point Flutter til Elixir (port 4000)
3. **Disable Rust**: Stop Rust gateway
4. **Monitor**: Check telemetry for errors

## Performance Forventninger

**Rust Proxy Overhead:**
- ~0.1-0.5ms per request (header injection)
- WebSocket: transparent proxy, minimal overhead
- Connection pooling til Elixir: reuse connections

**Total latency:**
- Handshake: 2-5ms (Rust only)
- Proxied requests: +0.5ms vs direct
- WebSocket: +0.1ms vs direct

**Akseptabelt?** Ja, for security og simplicity gains.
