# Sikkerhetsanalyse: Server <-> libmsgr protokoll

Analysert 2026-03-23. Dekker Rust Gateway, Flutter libmsgr, og Elixir backend.

---

## CRITICAL

### 1. Curve-mismatch: klient bruker P256, server bruker X25519

`noise_handshake_service.dart` genererer nokler på P256 (secp256r1)-kurven.
`patterns.rs` konfigurerer alle Noise-mønstre som `Noise_*_25519_AESGCM_SHA256`
(Curve25519). Disse er inkompatible elliptiske kurver.

Klienten poster sin P256 public key til `/noise/handshake`, og serveren lagrer
den som `device_key` (base64) uten å validere at det er en gyldig X25519-nøkkel.
gRPC `ValidateDevice` vil da se etter en P256-nøkkel i en database som kanskje
forventer X25519.

**Filer:** `flutter_frontend/packages/libmsgr/lib/src/noise_handshake_service.dart`,
`rust-gateway/src/noise/patterns.rs`

### 2. validate_device returnerer valid=true naar backend ikke er konfigurert

`grpc/service.rs`: hvis gRPC-backend-URL er `None`, returnerer `validate_device`
`valid: true, device_id: "unknown"`. En angriper som kan nå gatewayen uten
backend får full device-validering. Dette er dev-lokalstien, men det finnes ingen
konfigurasjonssperre for å forhindre at det når produksjon.

**Fil:** `rust-gateway/src/grpc/service.rs`

### 3. Signaturskjema er SHA256(key||data), ikke HMAC

`http/handlers.rs` beregner `SHA256(server_static_key || data)` som "signatur"
på handshake-responser. Dette er ikke en ekte MAC. SHA256(key||message) er
sårbart for length-extension-angrep. Bør være HMAC-SHA256 eller en AEAD-konstruksjon.
Klienten (libmsgr) verifiserer dette, saa begge sider deler samme svakhet.

**Fil:** `rust-gateway/src/http/handlers.rs`

---

## HIGH

### 4. Ingen meldingsframing — hver WebSocket-frame = én Noise-transportmelding

`noise_websocket.dart` behandler hver innkommende WS binary-frame som ett enkelt
Noise `read_message`-kall. Noise-transportmeldinger har et 16-byte auth-tag men
ingen lengdeforhånd. Hvis WS-laget fragmenterer eller samler binary frames (som
WebSocket-implementasjoner tillater), vil meldinger feile kryptografisk uten feilmelding.

Det finnes ingen eksplisitt lengdeframing mellom Noise og WebSocket. Dette
fungerer bare hvis WS-implementasjonen aldri fragmenterer binary-meldinger — en
skjor antagelse på tvers av ulike client-runtimes.

**Fil:** `flutter_frontend/packages/libmsgr/lib/src/noise_websocket.dart`

### 5. Session-tokens eksponert i REST-responser foør autentisering er fullført

`POST /noise/handshake` returnerer `session_id`, `session_token`, og `device_key`
i responsbody. Tokenet er en 32-byte tilfeldig verdi brukt som Bearer-token for
WebSocket-oppgradering — men klienten har ikke bevist eierskap til noen privat nøkkel
ennå. Handshaken er ikke fullført. Enhver som kan nå REST-endepunktet kan få en
gyldig session-token.

WebSocket-handleren sjekker tokenet, men tokenet deles ut fritt.

**Filer:** `rust-gateway/src/http/handlers.rs`, `rust-gateway/src/websocket/handler.rs`

### 6. In-memory session-store — ingen persistens, ingen klynging

`session/store.rs` bruker DashMap. Gateway-restarter mister alle sessions.
Ingen replikering. Ved flere gateway-instanser bak en load balancer kan en klient
som handshaker på instans A ikke koble via WebSocket til instans B.

**Fil:** `rust-gateway/src/session/store.rs`

---

## MEDIUM

### 7. Ingen rate limiting på handshake-endepunkt

`POST /noise/handshake` oppretter en ny session (og allokerer minne) ved hver
forespørsel. Eeste sperre er `max_sessions` i DashMap. Én klient kan eksaustere
denne grensen og nekte tjeneste for legitime klienter. Ingen per-IP eller
per-device-throttling.

**Fil:** `rust-gateway/src/http/handlers.rs`

### 8. PSK-distribusjon er out-of-band uten rotasjonsmekanisme

Alle tre mønstre (NKpsk0, XXpsk3, IKpsk2) bruker en pre-shared key. PSK
konfigureres via miljøvariabel (`SERVER_STATIC_KEY` / config.toml). Ingen
nøkkelrotasjon, versjonering, eller ratcheting. Når den er kompromittert,
kompromitteres alle sessions frem til manuell rotasjon.

**Filer:** `rust-gateway/src/noise/patterns.rs`, `rust-gateway/src/config/mod.rs`

### 9. Ingen replay-beskyttelse på handshake-meldinger

`process_message` i `handshake.rs` sporer eller avviser ikke replayede
handshake-meldinger. Noise Protocol gir ephemeral key exchange som gir noe
replay-resistens, men PSK-baserte mønstre (spesielt NKpsk0 hvor klienten kjenner
serverens statiske nøkkel) kan være sårbare for replay.

**Fil:** `rust-gateway/src/noise/handshake.rs`

### 10. Hardkodet 1-times TTL på klientsiden

`noise_handshake_service.dart` hardkoder 1-times TTL. Serverens standard er
300 sekunder (5 minutter) per `config.toml`. Hvis serveren avviser sessions med
TTL > 5 minutter, vil klientens 1-times forespørsel feile. Hvis serveren
aksepterer den, har klient og server ulike forventninger om session-levealder.

**Fil:** `flutter_frontend/packages/libmsgr/lib/src/noise_handshake_service.dart`

---

## LOW

### 11. Transport-overgang bruker mem::replace med dummy-state

`handshake.rs` linje 83-88: oppretter en kassert `Noise_NN_25519`-state som
swap-mål. Dette fungerer, men hvis `into_transport_mode()` feiler, går den
opprinnelige staten tapt og sessionen blir ubrukelig. Feilveien etterlater
sessionen i en korrupt tilstand.

**Fil:** `rust-gateway/src/noise/handshake.rs`

### 12. gRPC-backend-tilkobling bruker plaintext TCP som standard

`connect_to_backend` i `websocket/handler.rs` bruker `connect_async` uten TLS.
Backend-URL er konfigurerbar, men standardstien er plaintext. Gateway <-> Phoenix
backend-kommunikasjon (som bærer dekrypterte brukermeldinger) går over en
ukryptert kanal med mindre mTLS er eksplisitt konfigurert.

**Fil:** `rust-gateway/src/websocket/handler.rs`

### 13. Ingen eksplisitt maks meldingsstørrelse

`encrypt`/`decrypt` allokerer `ciphertext.len() + 16` og `ciphertext.len()`
buffere uten øvre grensesjekk. En ondsinnet klient kan sende svært store
ciphertext-frames og forårsake minnepress på gatewayen.

**Fil:** `rust-gateway/src/noise/handshake.rs`

---

## Oppsummering

| Alvorlighet | Antall | Hovedtemaer                                              |
| ----------- | ------ | ------------------------------------------------------- |
| Critical    | 3      | Curve-mismatch, åpen device-validering, ødelagt signatur |
| High        | 3      | Ingen framing, token-lekkasje før auth, ingen persistens |
| Medium      | 4      | Ingen rate limiting, PSK-håndtering, replay, TTL-mismatch |
| Low         | 3      | Feilhåndtering, plaintext backend-IPC, ingen størrelsesgrense |
