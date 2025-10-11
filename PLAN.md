# Produkt- og leveranseplan

## Visjon
Bygge en norsk meldingsplattform der én konto kan ha flere profiler og moduser (privat, jobb, familie) med sømløs sikker synk mellom enheter og en chat-opplevelse som føles rask, vakker og trygg.

## 12-ukers leveransemål
1. **Chat-MVP (uke 1-4)**
   - Mobil/web-klient leverer sanntids én-til-én-chat med historikk.
   - Backend har enhetlig bruker- og profilmodell, REST API + WebSocket for meldinger.
   - UI: fokus på “awesome” tekstfelt, rask sendeflyt, tydelig tilstedeværelse.
2. **Profiler & moduser (uke 5-8)**
   - Én global identitet med flere profiler, fargede temaer og policyer per modus.
   - Bygg onboarding (registrering, velg/lag profil, bytt modus) + lokal “safe key”.
3. **Synk & klientkvalitet (uke 9-12)**
   - Historikksynk mellom egne enheter, notifikasjoner, grunnleggende media-støtte.
   - Observability, crash-reporter, ytelsesmålinger (P95 send→levering < 500 ms).

## Arkitekturstrategi
- **Backend**: Phoenix monorepo (`apps/msgr` for domenelogikk, `apps/msgr_web` for API). Én Postgres-instans. PubSub/WebSocket via Phoenix Channels. Alle ekstra apper (Slack, Teams osv.) parkeres til senere.
- **Frontend**: Flutter-kodebases deles i features. Redux beholdes for global state, men chat-flyten flyttes til egen feature med `ChangeNotifier` for enklere iterasjon.
- **Kryptering**: Start med transport (TLS) + serverlagring, planlegg Double Ratchet senere. Design API slik at krypteringslag kan byttes ut.

## Fase 1 – Chat-MVP (detaljert)
1. **Backend**
   - Domain-modeller: `Account` (global bruker), `Profile` (modus), `Conversation`, `Participant`, `Message`.
   - Endpoints:
     - `POST /api/users` oppretter konto + første profil.
     - `POST /api/conversations` for 1:1 chat, automatisk opprett profil-deltakere.
     - `GET /api/conversations/:id/messages` og `POST /api/conversations/:id/messages`.
   - Phoenix Channel `ChatChannel` på `conversation:<id>` for sanntid.
   - Auth: midlertidig `x-user-id` header; bytt til OIDC/Noise senere.
   - Testing: ExUnit for kontomodell, meldingsstrøm, kanalbroadcast.

2. **Flutter**
   - Feature-mappe `lib/features/chat` med modeller, API-klient, view-model, widgets.
   - Chat UI: timeline med bobler, sticky dag-separator, typing-indikator, tilpasningsdyktig composer (emoji, vedlegg, voice stub).
   - Integrer i `HomePage`, legg inn states for “tom chat”, “laster”, “nettverksfeil”.
   - E2E: integrasjonstest mot lokal backend (mock server) + widgettester for composer.

3. **DevEx**
   - Skripter for å starte stack (`docker compose up backend postgres` + `flutter run`).
   - CI: Github Actions (lint, format, `mix test`, `flutter test`).
   - Observability stub: struktur for telemetry events (send→ack, typing, errors).

## Fase 2 – Profiler & moduser
- Modellér profiler med tema, varsler, sikkerhetspolicy (PIN/biometri flagg).
- API for å opprette/oppdatere profiler, bytte aktiv modus.
- UI: modus-switcher i toppbaren, tydelig farget banner, separate innboksfiltre.
- Autorisasjon: samtaler knyttes til profil, valider at brukeren eier profilen.

## Fase 3 – Historikksynk & kvalitet
- Arkitektur for enhetssynk (per-profil key store, delte backup-koder).
- Push varsler (FCM/APNs) med respekt for modus-policyer.
- Media: opplasting via presigned URL, lag placeholders for senere kryptering.
- Metrics-dashboard (Latency, leveringsrate, app start, composer performance).

## Langsiktig backlog (etter 12 uker)
- Interoperabilitet (Slack/Teams/WhatsApp etter DMA).
- Kanaler (broadcast + monetisering), P2P-modus, på sikt SRTP.
- Admin/Workspace, On-prem.

## Prinsipper for prioritering
1. Chat-opplevelse først – alt annet underordnes.
2. Enkelt å forklare: én konto → flere profiler → moduser.
3. Ship små, testbare iterasjoner ukentlig.
4. Design for kryptering/byttbar auth fra dag én.
5. Dokumenter alt – plan, API, arkitektur, teststrategi.
