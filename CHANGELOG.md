# Changelog

## Unreleased
- Replaced the Telegram/Matrix HTTP clients with queue-driven bridge facades for Telegram, Matrix, IRC, and XMPP plus a shared `ServiceBridge` helper and in-memory queue adapter tests.
- Introduced a queue behaviour contract to standardise `bridge/<service>/<action>` envelopes with trace IDs for all connectors.
- Updated bridge strategy, architecture, account linking, and platform research docs to focus on StoneMQ-backed daemons and MTProto-based Telegram support.
## [Unreleased]
### Added
- Konsolidert produktplan og forskningsoppsummering med fokus på chat-MVP, identitet og arkitektur.
- Ny domenemodell på backend for kontoer, profiler, samtaler og meldinger med REST API for chat.
- Sanntidsklar Flutter-chatopplevelse med ny `ChatPage`, timeline, og rik tekstkomponist.
- API-klient, view-model og tester for chatflyt i Flutter.
- CHANGELOG innført for å følge endringer.
- Widgettester for chat-komponisten for å sikre interaksjonene rundt sendeknappen.
- Dokumentert API-kontrakt for REST og WebSocket i `docs/api_contract.md`.
- Phoenix-basert samtale-kanal med PubSub-broadcast og Flutter-klient for sanntid.
- Passordløs autentisering med støtte for e-post, mobil og OIDC via `Auth`-kontekst og nye identitetsskjema.
- REST-endepunktene `/api/auth/challenge`, `/api/auth/verify` og `/api/auth/oidc` med JSON-svar og tester.
- OTP- og OIDC-dokumentasjon i `docs/api_contract.md` samt database-migrasjoner for identiteter og utfordringer.
- Flutter-støtte for OTP-flyt med `AuthChallenge`-modell, redux-tilstand og forbedret kodevisning.
- `msgr_messages`-bibliotek med tekst, markdown, kode og systemmeldinger, parser og omfattende enhetstester for gjenbruk i klientene.
- `msgr_messages`-biblioteket utvidet med bilde-, video- og lokasjonsmeldinger, felles temadefinisjon og parserstøtte med nye enhetstester.

### Changed
- Backend-konfigurasjon forenklet og unødvendige apper fjernet fra releaseoppsett.
- HomePage viser nå ny chatopplevelse i stedet for gamle lister.
- Chat-opplevelsen i Flutter har fått en modernisert visuell profil med felles tema, oppgradert tidslinje og raffinert komponist.
- ChatViewModel benytter nå sanntidsstrømmer og WebSocket-sending med HTTP-fallback.
- Innloggingsopplevelsen i Flutter er redesignet med glass-effekt, segmentert kanalvalg og OIDC-knapp.
- `RegistrationService` bruker nå de nye auth-endepunktene og returnerer strømlinjeformede brukersvar.
- `ChatMessage`-modellen i Flutter arver nå `MsgrTextMessage` og gjenbruker de delte msgr-modellene.
- `ChatMessage` JSON-serialisering inkluderer nå delt tema-informasjon slik at klienter kan bytte utseende konsistent.

### Fixed
- `mix` og Flutter-konfigurasjon oppryddet for å matche den nye strukturen.
