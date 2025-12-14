# Docker Compose Integration Test

Enkleste måten å kjøre full stack for integrasjonstesting.

## 🚀 Quick Start

```bash
# Start hele stacken (Postgres + Elixir + Rust Gateway)
docker-compose up -d db rust_gateway backend

# Sjekk at alt kjører
docker-compose ps

# Følg logger
docker-compose logs -f rust_gateway backend

# Test Noise handshake
curl -X POST http://localhost:8443/noise/handshake \
  -H 'Content-Type: application/json' \
  -d '{"pattern": "NKpsk0", "psk": "29GIxHhIZtoOxJAcTWO+xj77TCJSHfFmERNDZBFASVQ="}'

# Kjør Alice test klient
cd flutter_frontend/packages/libmsgr
dart test/integration/noise_gateway_test.dart --alice

# Stopp alt
docker-compose down
```

## 📋 Tjenester

### 1. PostgreSQL (`db`)
- Port: `5432`
- Database: `msgr_dev`
- User/Password: `postgres/postgres`

### 2. Rust Gateway (`rust_gateway`)
- HTTP API: `http://localhost:8443`
- gRPC Server: `localhost:50051` (for Elixir å kalle)
- Features:
  - Noise Protocol håndtering
  - Session management (in-memory)
  - HTTP reverse proxy til Elixir
  - Session context injection

### 3. Elixir Backend (`backend`)
- HTTP API: `http://localhost:4000` (via Rust proxy)
- gRPC Server: `localhost:50052` (for Rust å kalle)
- Features:
  - Business logic
  - PostgreSQL database
  - Phoenix Channels
  - OTP authentication

## 🔄 Arkitektur

```
┌────────────────────────────────────────────────────────┐
│                                                         │
│  Flutter Client (Host)                                  │
│        ↓                                                │
│  ┌─────────────────────────────────────────────┐      │
│  │  Docker Network: msgr_network                │      │
│  │                                              │      │
│  │  ┌──────────────────────────────┐           │      │
│  │  │  rust_gateway                 │           │      │
│  │  │  :8443 (HTTP)                 │           │      │
│  │  │  :50051 (gRPC)                │           │      │
│  │  └───────┬────────────┬──────────┘           │      │
│  │          │            │                       │      │
│  │          │ HTTP proxy │ gRPC                  │      │
│  │          │            │                       │      │
│  │  ┌───────▼────────────▼──────────┐           │      │
│  │  │  backend                       │           │      │
│  │  │  :4000 (HTTP)                  │           │      │
│  │  │  :50052 (gRPC)                 │           │      │
│  │  └────────────┬───────────────────┘           │      │
│  │               │                                │      │
│  │               ▼                                │      │
│  │  ┌────────────────────────┐                   │      │
│  │  │  db (PostgreSQL)        │                   │      │
│  │  │  :5432                  │                   │      │
│  │  └────────────────────────┘                   │      │
│  │                                              │      │
│  └─────────────────────────────────────────────┘      │
│                                                         │
└────────────────────────────────────────────────────────┘
```

## 🛠️ Vanlige Kommandoer

### Start kun nødvendige tjenester
```bash
# Kun database + backend + rust gateway
docker-compose up -d db backend rust_gateway
```

### Se logger
```bash
# Alle tjenester
docker-compose logs -f

# Kun Rust Gateway
docker-compose logs -f rust_gateway

# Kun Elixir Backend
docker-compose logs -f backend
```

### Rebuild etter kodeendringer
```bash
# Rebuild Rust Gateway
docker-compose build rust_gateway

# Rebuild Elixir Backend
docker-compose build backend

# Restart tjeneste
docker-compose restart rust_gateway
```

### Debug
```bash
# Kjør kommando i container
docker-compose exec backend mix ecto.migrate
docker-compose exec rust_gateway /bin/sh

# Se health status
curl http://localhost:8443/gateway/health
curl http://localhost:4000/api/health
```

## 🧪 Testing

### 1. Test Noise Handshake
```bash
curl -X POST http://localhost:8443/noise/handshake \
  -H 'Content-Type: application/json' \
  -d '{
    "pattern": "NKpsk0",
    "psk": "29GIxHhIZtoOxJAcTWO+xj77TCJSHfFmERNDZBFASVQ="
  }' | jq
```

Forventet response:
```json
{
  "session_id": "uuid-here",
  "session_token": "token-here",
  "device_key": "base64-key-here",
  "signature": "base64-signature-here",
  "expires_at": "2025-11-29T01:00:00Z"
}
```

### 2. Test gRPC (Rust → Elixir)
```bash
# Install grpcurl first: brew install grpcurl

grpcurl -plaintext \
  -d '{"device_public_key": "test_key"}' \
  localhost:50052 \
  noise.v1.NoiseBackend/ValidateDevice
```

### 3. Kjør CLI Test Klienter
```bash
cd flutter_frontend/packages/libmsgr

# Alice
dart test/integration/noise_gateway_test.dart --alice

# Bob (i annen terminal)
dart test/integration/noise_gateway_test.dart --bob
```

## 🐛 Troubleshooting

### Rust Gateway starter ikke
```bash
# Sjekk logger
docker-compose logs rust_gateway

# Vanlige problemer:
# 1. Port 8443 allerede i bruk
lsof -i :8443

# 2. Feil i .env
docker-compose exec rust_gateway env | grep SERVER_STATIC_KEY
```

### Elixir Backend kompilerer ikke
```bash
# Rebuild from scratch
docker-compose build --no-cache backend

# Sjekk dependencies
docker-compose exec backend mix deps.get
```

### Database connection errors
```bash
# Sjekk at postgres kjører
docker-compose ps db

# Kjør migrations
docker-compose exec backend mix ecto.migrate

# Reset database (DESTRUKTIVT!)
docker-compose exec backend mix ecto.reset
```

### gRPC connection failed
```bash
# Sjekk at begge gRPC servere lytter
lsof -i :50051  # Rust
lsof -i :50052  # Elixir

# Test connectivity mellom containers
docker-compose exec rust_gateway curl http://backend:50052
docker-compose exec backend curl http://rust_gateway:50051
```

## 📊 Monitoring

### Health Checks
```bash
# Rust Gateway
curl http://localhost:8443/gateway/health

# Elixir Backend
curl http://localhost:4000/api/health

# Database
docker-compose exec db pg_isready
```

### Ressursbruk
```bash
# Se CPU/minne
docker stats

# Kun våre containers
docker stats msgr_postgres msgr_rust_gateway msgr_backend
```

## 🔒 Sikkerhet

### Secrets
Secrets er satt i `docker-compose.yml` for dev/test. For produksjon:
- Bruk Docker secrets
- Eller miljøvariabler fra CI/CD
- Aldri commit secrets til git

### Nettverk
- Standard bridge network
- Kun nødvendige porter eksponert til host
- Inter-container kommunikasjon via service names

## 📝 Notater

- Første oppstart tar tid (Elixir compilation, ~2-3 min)
- Rust Gateway starter raskt (~5 sek)
- Database migrations kjøres automatisk
- Volumes bevarer data mellom restarts

## 🎯 Neste Steg

Etter vellykket Docker test:
1. ✅ Test full OTP flow (challenge → verify)
2. ✅ Test message sending (Alice → Bob)
3. ✅ Test WebSocket connections
4. 📦 Lag production-ready images
5. 🚀 Deploy til staging
