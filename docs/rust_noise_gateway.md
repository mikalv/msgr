# Rust Noise Gateway

## Oversikt

Dette dokumentet beskriver arkitekturen for Rust Noise Gateway - en dedikert tjeneste som offloader tung kryptografisk Noise Protocol-behandling fra Elixir/OTP backend til Rust for optimal ytelse og stabilitet.

## Problemstilling

### Opprinnelig Problem

Noise Protocol-implementasjon direkte i Elixir/OTP fører til:

- **BEAM VM Freezing**: Tungt kryptografisk arbeid blokkerer Erlang schedulers
- **Performance Issues**: Krypto-operasjoner er CPU-intensive og ikke optimalisert i BEAM
- **Scaling Limitations**: Kan ikke utnytte moderne CPU-instruksjoner (AES-NI, etc.)
- **Development Mode**: Måtte bruke stub (`DevHandshake`) som ikke gjør ekte Noise protocol

### Løsning

Rust Gateway Service som:

- Håndterer all Noise Protocol kryptografi i optimalisert Rust-kode
- Kommuniserer med Elixir backend via effektiv IPC (Unix Domain Sockets eller gRPC over mTLS)
- Kjører som egen prosess/tjeneste, isolert fra BEAM VM
- Utnytter moderne CPU-instruksjoner for maksimal ytelse

## Arkitektur

```
┌───────────────────────────────────────────────────────────────────┐
│                      Flutter Client                                │
│  • Dart Noise implementation (NKpsk0/XXpsk3)                      │
│  • HTTP/WebSocket support                                         │
└────────────────┬──────────────────────┬───────────────────────────┘
                 │                      │
        HTTPS    │                      │ WSS (efter handshake)
     (Handshake) │                      │
                 ▼                      │
┌─────────────────────────────────────┐│
│      Rust Gateway Service           ││
│  (Edge service for klienter)        ││
│  ┌──────────────────────────────┐   ││
│  │  HTTP/gRPC Server (tonic)    │   ││
│  │  • HTTPS listener (TLS 1.3)  │   ││
│  │  • Client authentication     │   ││
│  │  • Rate limiting             │   ││
│  └──────────────┬───────────────┘   ││
│                 │                    ││
│  ┌──────────────▼───────────────┐   ││
│  │  Noise Protocol Service      │   ││
│  │  • snow library              │   ││
│  │  • Handshake: NKpsk0/XXpsk3  │   ││
│  │  • Session management        │   ││
│  │  • HKDF key derivation       │   ││
│  │  • AES-GCM encrypt/decrypt   │   ││
│  └──────────────┬───────────────┘   ││
│                 │                    ││
│  ┌──────────────▼───────────────┐   ││
│  │  Session Store (DashMap)     │   ││
│  │  • In-memory sessions        │   ││
│  │  • TTL expiration            │   ││
│  │  • Concurrent access         │   ││
│  └──────────────────────────────┘   ││
│                                      ││
│  ┌──────────────────────────────┐   ││
│  │  Backend Integration         │   ││
│  │  • gRPC/UDS til Elixir       │   ││
│  │  • Session lifecycle hooks   │   ││
│  │  • OTP verification          │   ││
│  └──────────────┬───────────────┘   ││
└─────────────────┼───────────────────┘│
                  │                     │
    gRPC/UDS      │                     │
    (kryptert)    │                     │
                  ▼                     │
┌─────────────────────────────────────┐│
│      Elixir Backend (Phoenix)       ││
│  ┌──────────────────────────────┐   ││
│  │  RustGateway.Client (Elixir) │   ││
│  │  • Mottar callbacks          │   ││
│  │  • Session validation        │   ││
│  │  • OTP verification          │   ││
│  │  • Account/Profile binding   │   ││
│  └──────────────┬───────────────┘   ││
│                 │                    ││
│  ┌──────────────▼───────────────┐   ││
│  │  Business Logic              │   ││
│  │  • User management           │   ││
│  │  • Conversation handling     │   ││
│  │  • Message storage           │   ││
│  │  • Push notifications        │   ││
│  └──────────────┬───────────────┘   ││
│                 │                    ││
│  ┌──────────────▼───────────────┐   ││
│  │  Phoenix Channels            │◄──┘
│  │  • WebSocket endpoint        │
│  │  • Authenticated w/ Noise    │
│  │    session token             │
│  └──────────────────────────────┘
└─────────────────────────────────────┘
```

### Data Flow

**1. Handshake Flow (Ny klient):**
```
Flutter Client                Rust Gateway              Elixir Backend
      │                             │                          │
      │ POST /noise/handshake       │                          │
      │ (server_pk, psk)            │                          │
      ├────────────────────────────>│                          │
      │                             │                          │
      │                             │ Opprett session          │
      │                             │ Generer token            │
      │                             │                          │
      │                             │ Notify new session       │
      │                             ├─────────────────────────>│
      │                             │                          │
      │                             │                          │ Store metadata
      │                             │<─────────────────────────┤ Return OK
      │                             │                          │
      │ {session_id, token,         │                          │
      │  handshake_msg, signature}  │                          │
      │<────────────────────────────┤                          │
      │                             │                          │
      │ POST /api/auth/verify       │                          │
      │ (OTP, noise_session_id)     │                          │
      ├────────────────────────────────────────────────────────>│
      │                             │                          │
      │                             │ Verify session           │
      │                             │<─────────────────────────┤
      │                             │ {session_valid: true}    │
      │                             ├─────────────────────────>│
      │                             │                          │
      │                             │                          │ Bind Account
      │                             │                          │ to session
      │                             │                          │
      │ {noise_token, profile...}   │                          │
      │<────────────────────────────────────────────────────────┤
      │                             │                          │
      │ WSS /socket                 │                          │
      │ (noise_token)               │                          │
      ├────────────────────────────────────────────────────────>│
      │                             │                          │
      │                             │ Verify token             │
      │                             │<─────────────────────────┤
      │                             │ {account_id, profile_id} │
      │                             ├─────────────────────────>│
      │                             │                          │
      │                             │                          │ WebSocket
      │                             │                          │ authenticated!
      │<────────────────────────────────────────────────────────┤
```

**2. Eksisterende klient (med cached keys):**
```
Flutter Client                Rust Gateway              Elixir Backend
      │                             │                          │
      │ POST /noise/handshake       │                          │
      │ (pattern=XXpsk3,            │                          │
      │  client_static_key)         │                          │
      ├────────────────────────────>│                          │
      │                             │                          │
      │                             │ Mutual auth handshake    │
      │                             │                          │
      │                             │ Verify client key        │
      │                             ├─────────────────────────>│
      │                             │ {device_id, account_id}  │
      │                             │<─────────────────────────┤
      │                             │                          │
      │ {session_id, token}         │                          │
      │ (SKIP OTP!)                 │                          │
      │<────────────────────────────┤                          │
      │                             │                          │
      │ WSS /socket (noise_token)   │                          │
      ├────────────────────────────────────────────────────────>│
      │                             │                          │
```

## Kommunikasjonskanaler

### Klient ↔ Rust Gateway

Rust Gateway støtter **to transport modes** for fleksibilitet:

#### Mode 1: HTTP REST (Initial handshake)

**Use case:** Nye brukere, første registrering, eller når WebSocket ikke er tilgjengelig

**Transport:**
- **HTTP/2 over TLS 1.3** (HTTPS)
- **Endpoint**: `POST https://gateway.example.com/noise/handshake`
- **Request body**: JSON med Noise parameters
- **Response body**: JSON med session_id, token, handshake_message

**Flow:**
```
1. Flutter → POST /noise/handshake (pattern, psk)
2. Rust → Opprett Noise session
3. Rust → Return {session_id, token, handshake_msg}
4. Flutter → POST /api/auth/verify (OTP + noise_session_id) til Elixir
5. Elixir → Verifiser session via Rust Gateway gRPC
6. Flutter → WebSocket til Elixir Phoenix med noise_token
```

**Fordeler:**
- ✅ Standard HTTP - fungerer overalt
- ✅ Enkel debugging og monitoring
- ✅ Separasjon av bekymringer (handshake vs chat)
- ✅ Kompatibel med eksisterende kode

#### Mode 2: WebSocket (Re-authentication - fremtidig)

**Use case:** Eksisterende brukere med cached device keys, re-autentisering

**Transport:**
- **WebSocket over TLS 1.3** (WSS)
- **Endpoint**: `WSS wss://gateway.example.com/noise/ws`
- **Messages**: Binære Noise handshake frames

**Flow:**
```
1. Flutter → WSS connect to /noise/ws
2. Flutter → Send Noise handshake msg (binær)
3. Rust → Process handshake, complete session
4. Rust → Send session_token over WebSocket
5. Connection kan proxies til Elixir eller closes
```

**Fordeler:**
- ✅ Persistent connection
- ✅ Lavere latency for re-auth
- ✅ Binære messages (mindre overhead)
- ✅ Kan skip OTP hvis XXpsk3

**Etter handshake (begge modes):**
- Klient bruker **noise_token** for autentisering
- WebSocket til **Elixir Phoenix Channels** (`wss://backend/socket`)
- Channels validerer token via **Rust Gateway gRPC callback**

### Rust Gateway ↔ Elixir Backend

Dette er den interne kommunikasjonskanalen mellom de to services:

#### Option 1: mTLS (Mutual TLS) - Production

**Use Case**: Når Rust Gateway og Elixir kjører på separate servere/containers

```
┌─────────┐                           ┌──────────┐
│ Elixir  │ ←─── TLS 1.3 (mTLS) ───→ │   Rust   │
│ Backend │      client cert          │ Gateway  │
└─────────┘      server cert          └──────────┘
```

**Fordeler:**
- Sterk autentisering (både klient og server)
- Kryptert kommunikasjon over nettverk
- Kan kjøre på separate maskiner
- Industry standard for microservice security

**Implementasjon:**
- Rust: `rustls` + `tonic` med mTLS config
- Elixir: `:gun` eller `:grpc` med client certificates
- Certificate rotation support
- Certificate pinning for ekstra sikkerhet

**Konfigurasjon:**
```elixir
config :msgr, NoiseGateway.Client,
  transport: :mtls,
  endpoint: "https://noise-gateway.internal:50051",
  ca_cert: "/path/to/ca.pem",
  client_cert: "/path/to/client.pem",
  client_key: "/path/to/client-key.pem",
  verify_server: true
```

### Option 2: Unix Domain Socket (UDS) - Local/Development

**Use Case**: Når Rust Gateway kjører på samme maskin som Elixir backend

```
┌─────────┐                    ┌──────────┐
│ Elixir  │ ←─── UDS Socket ──→│   Rust   │
│ Backend │  /var/run/noise.sock│ Gateway  │
└─────────┘                    └──────────┘
```

**Fordeler:**
- **Ingen overhead**: Ingen TLS encryption (data aldri forlater maskinen)
- **Høyere throughput**: Raskere enn TCP/IP
- **OS-level permissions**: File system permissions for sikkerhet
- **Enklere deployment**: Ingen certificates å administrere

**Implementasjon:**
- Socket path: `/var/run/noise-gateway/noise.sock`
- File permissions: `0600` (kun backend user)
- Automatic socket cleanup ved shutdown
- Reconnection logic i Elixir client

**Konfigurasjon:**
```elixir
config :msgr, NoiseGateway.Client,
  transport: :uds,
  socket_path: "/var/run/noise-gateway/noise.sock",
  pool_size: 10
```

## Noise Handshake Patterns

Rust Gateway støtter tre Noise handshake patterns, optimalisert for chat-applikasjon hvor **klient initierer kontakt med server**:

### NKpsk0 (Anbefalt for enkel server-autentisering)

**Scenario:** Klient kjenner server's public key på forhånd (distribuert via app bundle eller API discovery).

**Flow:**
1. **Klient** har server's static public key
2. **Server** har sin static private key
3. **Begge** har en pre-shared key (PSK) - f.eks. fra OTP-verifisering
4. **Klient sender** første message med ephemeral key
5. **Server svarer** med ephemeral key
6. **Handshake ferdig** - kun server er autentisert

**Fordeler:**
- ✅ 2-message handshake (rask)
- ✅ Server autentisering garantert
- ✅ Forward secrecy
- ✅ Enkel klient-implementasjon

**Ulemper:**
- ❌ Klient er ikke autentisert i Noise layer (må gjøres via OTP etterpå)
- ❌ Server kan ikke verifisere klient's identitet før OTP

**Use case:** Standard chat-registrering hvor klient først etablerer sikker kanal, deretter autentiserer med OTP.

### XXpsk3 (Anbefalt for full mutual authentication)

**Scenario:** Verken klient eller server kjenner hverandres keys på forhånd. Begge utveksler identiteter.

**Flow:**
1. **Klient** genererer ephemeral key, sender til server
2. **Server** sender sin static + ephemeral public key tilbake
3. **Klient** sender sin static public key
4. **PSK brukes** i siste steg for ekstra sikkerhet
5. **Handshake ferdig** - begge er autentisert

**Fordeler:**
- ✅ Full mutual authentication
- ✅ Klient's static key sendes kryptert
- ✅ Server kan verifisere klient uten OTP
- ✅ Sterkeste sikkerhet

**Ulemper:**
- ❌ 3-message handshake (litt tregere)
- ❌ Krever at klient har persistent static key

**Use case:** Eksisterende brukere som re-autentiserer, enheter med etablert identitet.

### IKpsk2

**Scenario:** Klient sender sin identitet i første message, server kjenner klient's key.

**Flow:**
1. **Klient** sender static + ephemeral public key i første message
2. **Server** verifiserer klient's key, svarer med ephemeral key
3. **PSK brukes** tidlig i handshake
4. **Handshake ferdig** - klient autentisert tidlig

**Fordeler:**
- ✅ 2-message handshake
- ✅ Klient-autentisering i første message
- ✅ Server kan avvise ukjente klienter tidlig

**Ulemper:**
- ❌ Klient's static key sendes i klartekst (kun ephemeral encryption)
- ❌ Server må ha database av kjente klient-keys

**Use case:** High-trust miljøer med pre-registrerte enheter.

### Sammenligning

| Feature | NKpsk0 | XXpsk3 | IKpsk2 |
|---------|--------|--------|--------|
| Messages | 2 | 3 | 2 |
| Server auth | ✅ | ✅ | ✅ |
| Client auth | ❌ | ✅ | ✅ |
| Client identity hidden | ✅ | ✅ | ❌ |
| Forward secrecy | ✅ | ✅ | ✅ |
| Hastighet | Raskest | Middels | Rask |
| Kompleksitet | Enklest | Middels | Høy |

### Anbefaling for Chat-app

**For nye brukere / registrering:**
- Bruk **NKpsk0** for enkel server-autentisering
- Klient autentiserer senere med OTP
- Minimal latency, enkel implementasjon

**For eksisterende brukere:**
- Bruk **XXpsk3** for full mutual authentication
- Unngå OTP-steg hvis mulig
- Sterkeste sikkerhet for etablerte enheter

## API Design

### gRPC Service Definition

```protobuf
syntax = "proto3";

package noise.v1;

service NoiseGateway {
  // Opprett ny Noise handshake session
  rpc CreateHandshake(CreateHandshakeRequest) returns (CreateHandshakeResponse);

  // Prosesser handshake message fra klient
  rpc ProcessHandshakeMessage(HandshakeMessageRequest) returns (HandshakeMessageResponse);

  // Verifiser session token
  rpc VerifyToken(VerifyTokenRequest) returns (VerifyTokenResponse);

  // Krypter data med Noise session
  rpc Encrypt(EncryptRequest) returns (EncryptResponse);

  // Dekrypter data med Noise session
  rpc Decrypt(DecryptRequest) returns (DecryptResponse);

  // Slett session (cleanup)
  rpc DeleteSession(DeleteSessionRequest) returns (DeleteSessionResponse);

  // Health check
  rpc Health(HealthRequest) returns (HealthResponse);
}

// ===== CreateHandshake =====

message CreateHandshakeRequest {
  // Handshake pattern (NKpsk0, XXpsk3, IKpsk2)
  string pattern = 1;

  // Server's static public key (base64)
  string server_public_key = 2;

  // Pre-shared key (optional, base64)
  optional string psk = 3;

  // Session TTL i sekunder (default: 300)
  optional uint32 ttl_seconds = 4;

  // Initiator eller responder role
  bool is_initiator = 5;
}

message CreateHandshakeResponse {
  // Session ID (UUID)
  string session_id = 1;

  // Første handshake message (hvis initiator)
  optional bytes handshake_message = 2;

  // Session token for autentisering
  string session_token = 3;

  // Utløpstidspunkt (RFC3339)
  string expires_at = 4;

  // Server's device key (base64)
  string device_key = 5;

  // HMAC signature av handshake hash
  string signature = 6;
}

// ===== ProcessHandshakeMessage =====

message HandshakeMessageRequest {
  // Session ID
  string session_id = 1;

  // Session token for auth
  string session_token = 2;

  // Handshake payload fra klient
  bytes message = 3;
}

message HandshakeMessageResponse {
  // Respons message (hvis nødvendig)
  optional bytes response_message = 1;

  // True hvis handshake er ferdig
  bool handshake_complete = 2;

  // Oppdatert session token
  string session_token = 3;
}

// ===== VerifyToken =====

message VerifyTokenRequest {
  // Session token å verifisere
  string session_token = 1;
}

message VerifyTokenResponse {
  // True hvis token er gyldig
  bool valid = 2;

  // Session ID (hvis gyldig)
  optional string session_id = 3;

  // Gjenværende TTL i sekunder
  optional uint32 remaining_ttl = 4;

  // Session metadata
  map<string, string> metadata = 5;
}

// ===== Encrypt =====

message EncryptRequest {
  // Session ID eller token
  string session_id = 1;
  string session_token = 2;

  // Plaintext data
  bytes plaintext = 3;

  // Associated data for AEAD (optional)
  optional bytes associated_data = 4;
}

message EncryptResponse {
  // Encrypted ciphertext (med auth tag)
  bytes ciphertext = 1;

  // Nonce brukt (for debugging)
  bytes nonce = 2;
}

// ===== Decrypt =====

message DecryptRequest {
  // Session ID eller token
  string session_id = 1;
  string session_token = 2;

  // Ciphertext data
  bytes ciphertext = 3;

  // Associated data for AEAD (optional)
  optional bytes associated_data = 4;
}

message DecryptResponse {
  // Decrypted plaintext
  bytes plaintext = 1;
}

// ===== DeleteSession =====

message DeleteSessionRequest {
  string session_id = 1;
  string session_token = 2;
}

message DeleteSessionResponse {
  bool deleted = 1;
}

// ===== Health =====

message HealthRequest {}

message HealthResponse {
  string status = 1; // "SERVING" | "NOT_SERVING"
  uint64 active_sessions = 2;
  uint64 uptime_seconds = 3;
}
```

## Teknologi Stack

### Rust Gateway Dependencies

```toml
[dependencies]
# Async runtime
tokio = { version = "1", features = ["full"] }

# gRPC server/client
tonic = "0.11"
prost = "0.12"

# Noise Protocol implementation
snow = "0.9"

# Kryptografi
aes-gcm = "0.10"
x25519-dalek = "2"
ed25519-dalek = "2"
sha2 = "0.10"
hkdf = "0.12"
rand = "0.8"

# Concurrent hashmap
dashmap = "5"

# TLS
rustls = "0.22"
tokio-rustls = "0.25"

# Unix Domain Sockets
tokio-stream = "0.1"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Time/Duration
chrono = "0.4"

# UUID
uuid = { version = "1", features = ["v4", "serde"] }

# Base64
base64 = "0.21"

# Logging
tracing = "0.1"
tracing-subscriber = "0.3"

# Error handling
anyhow = "1"
thiserror = "1"

[build-dependencies]
tonic-build = "0.11"
```

### Elixir Backend Dependencies

```elixir
defp deps do
  [
    # gRPC client
    {:grpc, "~> 0.7"},
    {:gun, "~> 2.0"},

    # Connection pooling
    {:poolboy, "~> 1.5"},

    # TLS certificates
    {:castore, "~> 1.0"},

    # Telemetry
    {:telemetry, "~> 1.0"},
  ]
end
```

## Sikkerhet

### Autentisering og Autorisasjon

#### mTLS Mode
- **Client Certificate**: Elixir backend har client certificate signert av CA
- **Server Certificate**: Rust gateway har server certificate signert av samme CA
- **Certificate Validation**: Begge parter validerer certificates mot CA
- **Certificate Revocation**: Support for CRL eller OCSP
- **Certificate Rotation**: Hot-reload av certificates uten downtime

#### Unix Socket Mode
- **File Permissions**: Socket fil har `0600` permissions
- **User/Group**: Kun backend user kan lese/skrive
- **Socket Directory**: `/var/run/noise-gateway/` owned by backend user
- **SELinux/AppArmor**: Policy rules for socket access (production)

### Session Security

- **Session Tokens**: Cryptographically secure random 32 bytes
- **Token Encoding**: Base64-URL safe encoding
- **TTL**: Default 5 minutes, configurable
- **Automatic Cleanup**: Tokio timer sletter expired sessions
- **Rate Limiting**: Per-IP rate limiting for handshake creation

### Kryptografiske Garantier

- **Forward Secrecy**: Ephemeral keys for hver handshake
- **Key Derivation**: HKDF-SHA256 for all key material
- **AEAD**: AES-GCM for authenticated encryption
- **Nonce Management**: Strict nonce counter, panic ved overflow
- **Constant-Time Comparisons**: For HMAC og signature verification

## Deployment

### Development Setup

```bash
# Start Rust gateway (Unix socket mode)
cd rust-gateway
cargo run --release -- --socket /tmp/noise-gateway.sock

# Elixir config
export NOISE_GATEWAY_TRANSPORT=uds
export NOISE_GATEWAY_SOCKET=/tmp/noise-gateway.sock

# Start Elixir backend
cd backend
mix phx.server
```

### Production Deployment

#### Docker Compose

```yaml
version: '3.8'

services:
  rust-gateway:
    image: msgr/noise-gateway:latest
    volumes:
      - /var/run/noise-gateway:/var/run/noise-gateway
      - ./certs:/certs:ro
    environment:
      - RUST_LOG=info
      - TRANSPORT_MODE=uds
      - SOCKET_PATH=/var/run/noise-gateway/noise.sock
      # eller for mTLS:
      # - TRANSPORT_MODE=mtls
      # - TLS_CERT=/certs/server.pem
      # - TLS_KEY=/certs/server-key.pem
      # - TLS_CA=/certs/ca.pem
    healthcheck:
      test: ["CMD", "grpc-health-probe", "-addr=unix:/var/run/noise-gateway/noise.sock"]
      interval: 10s
      timeout: 5s
      retries: 3

  elixir-backend:
    image: msgr/backend:latest
    depends_on:
      - rust-gateway
    volumes:
      - /var/run/noise-gateway:/var/run/noise-gateway
    environment:
      - NOISE_GATEWAY_TRANSPORT=uds
      - NOISE_GATEWAY_SOCKET=/var/run/noise-gateway/noise.sock
```

#### Kubernetes

```yaml
apiVersion: v1
kind: Service
metadata:
  name: noise-gateway
spec:
  selector:
    app: noise-gateway
  ports:
    - port: 50051
      targetPort: 50051
      protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: noise-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: noise-gateway
  template:
    metadata:
      labels:
        app: noise-gateway
    spec:
      containers:
      - name: gateway
        image: msgr/noise-gateway:latest
        ports:
        - containerPort: 50051
        env:
        - name: TRANSPORT_MODE
          value: "mtls"
        - name: TLS_CERT
          value: "/certs/server.pem"
        - name: TLS_KEY
          value: "/certs/server-key.pem"
        - name: TLS_CA
          value: "/certs/ca.pem"
        volumeMounts:
        - name: certs
          mountPath: /certs
          readOnly: true
        resources:
          requests:
            cpu: "500m"
            memory: "256Mi"
          limits:
            cpu: "2000m"
            memory: "1Gi"
        livenessProbe:
          grpc:
            port: 50051
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          grpc:
            port: 50051
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: certs
        secret:
          secretName: noise-gateway-certs
```

### Monitoring og Observability

#### Metrics (Prometheus)

```rust
// Rust gateway exports metrics på /metrics endpoint
- noise_gateway_active_sessions
- noise_gateway_handshakes_total
- noise_gateway_handshakes_failed_total
- noise_gateway_encrypt_operations_total
- noise_gateway_decrypt_operations_total
- noise_gateway_request_duration_seconds
- noise_gateway_session_ttl_seconds
```

#### Tracing (OpenTelemetry)

```rust
// Distributed tracing support
- Span propagation via gRPC metadata
- Trace context injection/extraction
- Integration med Jaeger/Tempo
```

#### Logging

```rust
// Structured logging med tracing-subscriber
{
  "timestamp": "2024-10-28T12:00:00Z",
  "level": "INFO",
  "target": "noise_gateway::handshake",
  "message": "Handshake created",
  "session_id": "uuid-here",
  "pattern": "NKpsk0",
  "ttl": 300
}
```

## Migrering fra DevHandshake

### Fase 1: Parallel Mode

1. Deploy Rust gateway
2. Konfigurer Elixir til å kalle Rust gateway, men fallback til DevHandshake ved feil
3. Monitor success rate via telemetry
4. Gradually increase traffic til Rust gateway

```elixir
defmodule Messngr.Noise.HandshakeRouter do
  @doc """
  Routes handshake creation to either Rust gateway or DevHandshake fallback.

  Pattern selection:
  - NKpsk0: Client knows server's public key (recommended for simple auth)
  - XXpsk3: Mutual authentication, neither knows other's key
  - IKpsk2: Client sends identity in first message
  """
  def create_handshake(params) do
    if FeatureFlags.enabled?(:rust_gateway_handshake) do
      case NoiseGateway.Client.create_handshake(params) do
        {:ok, result} ->
          Telemetry.execute([:noise, :rust_gateway, :success])
          {:ok, result}
        {:error, reason} ->
          Telemetry.execute([:noise, :rust_gateway, :fallback])
          DevHandshake.create_handshake(params)
      end
    else
      DevHandshake.create_handshake(params)
    end
  end
end
```

### Fase 2: Full Cutover

1. Rust gateway til 100% traffic
2. Remove DevHandshake fallback
3. Delete DevHandshake module

### Fase 3: Optimization

1. Fine-tune session TTLs
2. Optimize connection pooling
3. Enable advanced features (session persistence, etc.)

## Performance Forventninger

### Baseline (DevHandshake i Elixir)
- Handshake creation: ~1ms (ingen ekte crypto)
- Session verification: ~0.1ms
- **Problem**: Ikke ekte sikkerhet

### Rust Gateway (Unix Socket)
- Handshake creation: ~2-5ms (ekte Noise protocol)
- Session verification: ~0.2ms
- Encrypt/Decrypt: ~0.1ms per operation
- IPC overhead: ~0.05ms

### Rust Gateway (mTLS)
- Handshake creation: ~3-7ms (Noise + TLS overhead)
- Session verification: ~0.3ms
- TLS overhead: ~1-2ms per request

### Throughput
- Expected: 10,000+ handshakes/sec på moderne CPU
- Max concurrent sessions: 1,000,000+ (limited by RAM)

## Fremtidige Utvidelser

### Session Persistence
- Redis/PostgreSQL backing for session store
- Survive gateway restarts
- Multi-instance session sharing

### Advanced Handshake Patterns
- XX pattern (mutual authentication)
- IK pattern (known initiator key)
- Custom patterns for specific use cases

### Hardware Security Module (HSM)
- Store server static keys i HSM
- PKCS#11 interface
- Cloud KMS integration (AWS KMS, Google Cloud KMS)

### Zero-Copy Optimizations
- Shared memory transport (vs Unix sockets)
- Memory-mapped files for large payloads
- io_uring for Linux systems

## Referanser

- [Noise Protocol Framework Spec](http://www.noiseprotocol.org/noise.html)
- [snow - Rust Noise implementation](https://github.com/mcginty/snow)
- [tonic - Rust gRPC framework](https://github.com/hyperium/tonic)
- [Existing Noise handshake rollout plan](./noise_handshake_rollout.md)
- [Backend Architecture](./backend_setup.md)
