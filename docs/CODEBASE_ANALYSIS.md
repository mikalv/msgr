# Kodebase-analyse: msgr

**Analysedato:** 2026-07-31 (statusoppdatert 2026-08-17)  
**Versjon:** 0.1.1

---

## Sammendrag

**msgr** er en eksperimentell norsk/europeisk personvern-fokusert meldingsplattform bygget som et monorepo. Prosjektet har en solid arkitektur med E2EE-design, multi-profil støtte, og GDPR-først tilnærming. Det er **utviklingsklart** og har god **lokal dev-stack**, men mangler flere kritiske elementer for produksjon.

Siden første analyse er bl.a. 1:1 E2EE (Double Ratchet), team-media ClamAV-pipeline, CI (credo/sobelow/dialyzer/coveralls/integration), og manuell sikkerhetsgjennomgang levert — se tabellene under.

---

## 1. Implementerte Features

### 1.1 Backend (Elixir/Phoenix)

| Feature | Status | Detaljer |
|---------|--------|----------|
| **Kontoer & Profiler** | ✅ Implementert | Accounts, profiles, devices, key store |
| **Autentisering** | ✅ Implementert | OTP/SMS, OIDC, JWT (Guardian), refresh tokens |
| **Chat/Meldinger** | ✅ Implementert | Conversations, messages, receipts, reactions, threads, pins |
| **Media** | ✅ Implementert | Presigned S3/MinIO uploads, retention pruning; team ClamAV scan/quarantine (se `docs/media_virus_scan.md`) |
| **Realtime** | ✅ Implementert | Phoenix Channels (Conversation, Device, RTC) |
| **Rate Limiting** | ✅ Implementert | Hammer-basert (auth: 5/10min, meldinger: 60/min) |
| **Teams/Workspaces** | ✅ Implementert | Multi-tenant, channels, DMs, invites, reminders |
| **Bridge connectors** | ⚠️ Delvis | Slack, Telegram, Signal, Matrix, WhatsApp, Teams, Snapchat (strukturer finnes) |
| **App Platform** | ✅ Implementert | Marketplace, webhooks, slash commands |
| **LLM Gateway** | ⚠️ Delvis | Grunnleggende integrasjon, dekryptering ikke implementert |
| **Push Notifications** | ✅ Implementert | FCM/APNs, privacy-aware payloads, modus-basert policy |
| **Metrics/Observability** | ✅ Implementert | Prometheus, Grafana, OpenObserve, strukturert logging |
| **CSRF Protection** | ✅ Implementert | `protect_from_forgery` i alle routers |
| **CORS** | ✅ Implementert | CORSPlug på auth_provider og teams |

### 1.2 Rust Gateway

| Feature | Status | Detaljer |
|---------|--------|----------|
| **Noise Protocol** | ✅ Implementert | snow-basert handshake, session management |
| **gRPC Backend** | ✅ Implementert | tonic-basert kommunikasjon med Elixir |
| **Metrics** | ✅ Implementert | Handshakes, sessions, latency histograms |
| **WebSocket Proxy** | ✅ Implementert | Kryptert WS-forwarding |

### 1.3 Flutter Client

| Feature | Status | Detaljer |
|---------|--------|----------|
| **Auth** | ⚠️ Delvis | OTP/OIDC flow, mange TODO-er |
| **Chat UI** | ✅ Implementert | Bubbles, composer, realtime state (Riverpod) |
| **E2EE (1:1 text)** | ✅ Implementert | XX Double Ratchet i `libmsgr_core` + OMEMO store / `E2eeService`; media CEK og Sender Keys ute av scope (`docs/e2ee_spec.md`) |
| **Noise Protocol** | ✅ Implementert | Full implementasjon i `libmsgr` |
| **Local Storage** | ✅ Implementert | Hive/Sembast/Drift, secure storage |
| **WebRTC** | ✅ Implementert | 1:1 voice/video via `RTCChannel` + Flutter `CallProvider` / `flutter_webrtc` |
| **Bridges UI** | ⚠️ Delvis | Catalog og session management struktur |
| **Contacts** | ⚠️ Delvis | Import/lookup strukturer |

### 1.4 Infrastruktur

| Komponent | Status | Detaljer |
|-----------|--------|----------|
| **Docker Compose** | ✅ Komplett | PG, Redis, MinIO, StoneMQ, coturn, ClamAV, etc. |
| **CI (GitHub Actions)** | ✅ Fungerer | Backend tests + credo/sobelow/dialyzer/coveralls, Flutter tests, Docker pytest integration — se `docs/ci_and_coverage.md` |
| **Deploy Pipeline** | ✅ Fungerer | SSH/rsync til `/var/www/msgr.no`, systemd |
| **Prometheus/Grafana** | ✅ Konfigurert | Pre-provisioned dashboards |
| **OpenObserve** | ✅ Konfigurert | Log aggregation |
| **TURN Server** | ✅ Konfigurert | coturn for WebRTC relay |

---

## 2. Mangler og TODO-er

### 2.1 Kritiske TODO-er i Kode

**Backend:**
```
- msgr/application.ex: Noise.Registry og gRPC proto/endpoint modules deaktivert
- msgr/auth.ex: switch_profile uten Noise SessionStore
- rust_gateway/client.ex: Mangler connection pooling
- apps/executors/llm_executor.ex: Dekryptering ikke implementert
```

**Flutter:**
```
- database/database.dart: Database-passord generering/lagring ikke implementert
- device_info_impl.dart: Trenger refactor for bedre device ID
- login_screen.dart: Flere auth flows ikke fullført
- websocket_provider.dart: Typing indicator ikke implementert
- inner_drawer.dart: Flere "Handle this case" TODO-er
```

### 2.2 Fra Todo.md

- [ ] Bedre error handling (mobil vs desktop abstraksjoner)
- [ ] Preferences State object (brukerinnstillinger)
- [ ] Asynkron meldingslasting
- [ ] Redigering av sendte meldinger
- [ ] Link preview
- [ ] Fil-opplasting (UI-siden)
- [ ] Connectivity status indikator
- [ ] Push-varsler (klient-side)
- [ ] Lest-status for meldinger
- [ ] Paginering

---

## 3. Mangler for Produksjon

### 3.1 🔴 Kritisk (Blokkere)

| Mangel | Beskrivelse | Prioritet |
|--------|-------------|-----------|
| **E2EE gaps** | 1:1 tekst er på plass; media CEK (`#236`), Sender Keys (`#237`), bedre device discovery (`#235`) mangler | P0 |
| **Secret Management (prod)** | Compose/dev bruker `.env` (se `docs/SECRET_MANAGEMENT.md`); prod vault/rotasjon fortsatt åpent | P0 |
| **Database HA** | Ingen Patroni/HA-konfigurasjon | P0 |
| **Database Backup** | Ingen backup-strategi dokumentert/implementert | P0 |
| **SSL/TLS Sertifikater** | Produksjon krever gyldige sertifikater, kun toggle-støtte | P0 |
| **Uavhengig Security Audit** | Manuell review i `docs/SECURITY_REVIEW.md` (SEC-1–8 fikset); ekstern revisjon/pentest (`#196`) mangler | P0 |

### 3.2 🟠 Høy Prioritet

| Mangel | Beskrivelse | Prioritet |
|--------|-------------|-----------|
| **Test Coverage depth** | Umbrella coveralls + CI-artifact finnes; mange suiter i `**/test/pending_*`, floor under 70%-mål — restore-prosess i `docs/ci_and_coverage.md` | P1 |
| **Rust Gateway Tests i CI** | cargo test ikke i workflow | P1 |
| **CDN** | Ingen EU-edge CDN for media | P1 |
| **Error Tracking** | Sentry nevnt i docs men ikke konfigurert | P1 |
| **GDPR DPIA** | Nevnt som krav, ikke dokumentert | P1 |
| **Rate Limiting Tuning** | Kun grunnleggende limits, trenger prod-tuning | P1 |
| **Connection Pooling** | gRPC client mangler pooling | P1 |

### 3.3 🟡 Medium Prioritet

| Mangel | Beskrivelse | Prioritet |
|--------|-------------|-----------|
| **PG Sharding** | Citus for messages nevnt men ikke implementert | P2 |
| **Media Lifecycle** | Hot→warm→cold archival ikke implementert | P2 |
| **Bug Bounty Program** | Nevnt i spec, ikke etablert | P2 |
| **SLA Monitoring** | 99.9% uptime mål uten monitoring-verktøy | P2 |
| **Key Attestation** | Key Directory attestasjonslogg ikke fullført | P2 |
| **History Sync D2D** | QR/Nearby/P2P sync delvis implementert | P2 |
| **Licensing** | Ingen LICENSE-fil i repo | P2 |

### 3.4 🟢 Lav Prioritet / Nice-to-have

| Mangel | Beskrivelse | Prioritet |
|--------|-------------|-----------|
| **Enterprise SSO** | Fase 3+ | P3 |
| **On-prem Deploy** | Ikke-mål for første faser | P3 |
| **DMA Bridges** | Avhengig av leverandør-API | P3 |
| **Notif-AI (on-device)** | Fase 2 feature | P3 |

---

## 4. Arkitektur-vurdering

### 4.1 Styrker

1. **Modulær umbrella-struktur** - Klare grenser mellom apps
2. **Feature toggles** - TLS/Noise/Redis via env-vars uten kodeendringer
3. **Crypto offload pattern** - Rust for tung krypto, Elixir for business logic
4. **Privacy-first design** - Metadata-only på server, E2EE-klare strukturer
5. **Comprehensive observability** - Prometheus + Grafana + OpenObserve
6. **Multi-profile architecture** - Privat/Jobb/Familie med separate policies

### 4.2 Bekymringer

1. **E2EE ikke komplett for alle modus** - 1:1 tekst OK; media/grupper og team-modus fortsatt plaintext
2. **Noise modules disabled** - `Transport.Noise.Registry` og gRPC endepunkter kommentert ut
3. **Coverage under mål** - CI rapporterer coveralls, men mange parked suiter
4. **Single point of failure** - Postgres uten HA i docker-compose
5. **Prod secret store** - Dev/compose er `.env`-basert; vault/rotasjon for prod mangler

---

## 5. Anbefalinger

### Fase 1: Sikkerhet & Stabilitet (Pre-prod)

1. ~~**Implementer Double Ratchet E2EE**~~ — 1:1 tekst levert; gjenstår media CEK / Sender Keys
2. **Prod secret store** - Vault/rotasjon utover `.env` (dev cleanup gjort)
3. **Sett opp database HA** - Patroni eller managed PostgreSQL
4. **Implementer backup-strategi** - pg_dump + S3/MinIO backup
5. ~~**Legg til virusskanning**~~ — team ClamAV pipeline levert (`docs/media_virus_scan.md`)
6. ~~**Kjør security tools i CI**~~ — credo --strict, sobelow, dialyxir i workflow

### Fase 2: Kvalitet & Observability

1. ~~**Test coverage reporting**~~ — umbrella coveralls + CI artifact (hev terskel / gjenopprett pending)
2. ~~**Integration tests i CI**~~ — Docker-basert pytest i workflow
3. **Sentry/error tracking** - Klient og server
4. **CDN-oppsett** - Cloudflare/Bunny for EU-edge

### Fase 3: Compliance & Skalering

1. **GDPR DPIA dokumentasjon** - Formell vurdering
2. **Citus sharding** - For message-tabellen
3. **Media lifecycle** - Automated archival
4. **Bug bounty** - Formelt program

---

## 6. Teknisk Stack Oversikt

```
┌─────────────────────────────────────────────────────────────┐
│                        KLIENTER                             │
├─────────────────────────────────────────────────────────────┤
│  Flutter App          │  Bridge SDKs      │  Web Client     │
│  - Riverpod           │  - Python         │  (planlagt)     │
│  - go_router          │  - Go             │                 │
│  - libmsgr/libmsgr_core                                     │
│  - flutter_webrtc                                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      EDGE LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  Rust Gateway         │  Phoenix msgr_web │  auth_provider  │
│  - Noise Protocol     │  - REST API       │  - OIDC/OAuth   │
│  - gRPC ←→ Elixir     │  - WebSocket      │  - Boruta       │
│  - Session mgmt       │  - Channels       │                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    BUSINESS LOGIC                           │
├─────────────────────────────────────────────────────────────┤
│  msgr (core)     │  teams          │  family_space         │
│  - Accounts      │  - Multi-tenant │  - Shopping lists     │
│  - Chat          │  - Channels     │  - Events             │
│  - Media         │  - Search       │  - Notes              │
│  - Bridges       │  - Apps         │                       │
│  - Notifications │                 │                       │
├─────────────────────────────────────────────────────────────┤
│  llm_gateway     │  slack_api      │  edge_router          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL 15   │  Redis 7        │  MinIO/S3             │
│  - 39 migrations │  - Sessions     │  - Media blobs        │
│  - Ecto          │  - Cache        │  - Presigned URLs     │
├─────────────────┬┴─────────────────┴──────────────────────┤
│  StoneMQ        │  Prism Search                           │
│  - Event queue  │  - Full-text (PG fallback)              │
└─────────────────┴─────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY                            │
├─────────────────────────────────────────────────────────────┤
│  Prometheus      │  Grafana        │  OpenObserve          │
│  - Metrics       │  - Dashboards   │  - Logs               │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Test-status

| Område | Antall filer | CI | Coverage |
|--------|--------------|-----|----------|
| Backend Elixir | 129 | ✅ | ❌ Ikke rapportert |
| Flutter/Dart | 88 | ✅ | ❌ Ikke rapportert |
| Rust Gateway | Ukjent | ❌ | ❌ |
| Integration | 1+ | ❌ | N/A |

---

## 8. Konklusjon

**msgr** er et ambisiøst prosjekt med solid arkitektur og god modularitet. For **MVP/beta** trengs primært:

1. Fullføring av E2EE (Double Ratchet)
2. Security hardening (secrets, scanning)
3. Database reliability (HA, backup)
4. CI/CD forbedringer (quality gates, coverage)

For **produksjon** kreves i tillegg:
- Sikkerhetsrevisjon
- GDPR DPIA
- CDN og skaleringsinfrastruktur
- Feilsporing og SLA-monitoring

Estimert arbeid til beta: Betydelig - E2EE-implementasjon er kompleks og kritisk.
Estimert arbeid til prod: Avhengig av beta-feedback og compliance-krav.
