# MVP1 – Første testrunde (to klienter kan chatte)

Målet er å starte backend og to klienter, registrere/innlogge brukere, finne hverandre og sende meldinger i sanntid uten at workspace/team er et krav. Planen er delt i backend, frontend og dev/test.

## Backend
- **Session-respons med profil**: Utvid OTP-responsen slik at `profile_id` returneres sammen med `account` (`backend/apps/msgr_web/lib/msgr_web/controllers/auth_json.ex:19`). Klienten trenger disse ID-ene umiddelbart etter innlogging.
- **Default profilnavn**: Når `create_account` lager første profil, bruk kontonavnet som default slik at samtalelisten får meningsfulle navn (`backend/apps/msgr/lib/msgr/accounts.ex:41-60`).
- **Noise-handshake i dev**: Tilby et feature-togglable endpoint som utsteder en ferdig Noise-sesjon for OTP (`backend/apps/msgr/lib/msgr/noise/dev_handshake.ex`, `backend/apps/msgr_web/lib/msgr_web/controllers/noise_handshake_controller.ex`). Skal kun brukes i utvikling mens transporten bygges ferdig.
- **Direktesamtaler og Noise-token**: Dokumenter og sikre at `POST /api/conversations` med `target_profile_id` oppretter direkte-samtale, og at alle API-kall validerer `Authorization: Noise <token>` via `CurrentActor`-pluggen (`backend/apps/msgr_web/lib/msgr_web/controllers/conversation_controller.ex:15-22`, `backend/apps/msgr_web/lib/msgr_web/plugs/current_actor.ex:15-26`).
- **Account-API**: Legg til eller gjenbruk endpoint for «min konto» slik at klienten kan hente kontoen uten å hente alle brukere (kan baseres på `AccountController` og `Accounts`-logikk).
- **Kontaktoppslag**: Verifiser at `import_contacts` og `lookup_known_contacts` dekker brukersøk (returner profilinfo når den finnes) (`backend/apps/msgr/lib/msgr/accounts.ex:145-210`).
- **Dev-konfig**: Hold `expose_otp_codes` aktiv i dev, sørg for CORS der det trengs, og beskriv `docker compose up` som anbefalt måte å starte stacken på (`docker-compose.yml`).

## Frontend
- **OTP + Noise-login**: Bytt ut demodata med faktisk OTP/Noise-flow i dev-login (`flutter_frontend/lib/features/auth/dev_login_page.dart`), lagre `AccountIdentity` med Noise-token i `AuthIdentityStore` (`flutter_frontend/lib/features/auth/auth_identity_store.dart`).
- **Onboarding uten workspace**: Bygg enkel UI for registrering/OTP (bruk `AuthController`-endpoints), vis debug-koder i dev og persistér ID-ene lokalt.
- **Navigasjon**: Tillat chat uten valgt team ved å fjerne `teamAccessToken`-kravet i `AppNavigation.redirectWhenLoggedIn` og depreker `SelectCurrentTeamScreen` (`flutter_frontend/lib/config/AppNavigation.dart:136-159`, `flutter_frontend/lib/ui/screens/select_current_team_screen.dart`).
- **Start ny samtale**: Lag UI for kontaktoppslag og oppstart av direkte-samtale via `ContactApi.lookupKnownContacts` og `ChatApi.ensureDirectConversation` (`flutter_frontend/lib/services/api/contact_api.dart`, `flutter_frontend/lib/services/api/chat_api.dart`).
- **Backend-konfig i UI**: Eksponer mulighet til å endre backend-host i dev ved å kalle `BackendEnvironment.override`, slik at to klienter kan peke på samme backend uten rebuild (`flutter_frontend/lib/config/backend_environment.dart`).
- **Websocket-robusthet**: Sikre reconnect og brukerfeedback i `ChatSocket` og `ChatViewModel` (monitorer `_buildEndpoint`, reconnect og feil) (`flutter_frontend/lib/services/api/chat_socket.dart:417-456`).

## Dev & Test
- **Startscript**: Dokumenter flyten – `NOISE_TRANSPORT_ENABLED=true docker compose up`, kjør `flutter run --dart-define=MSGR_BACKEND_HOST=<host>`, gjennomfør Noise-handshake/OTP, importer hverandres e-post og start chat.
- **Tester**:
  - Backend: ExUnit som verifiserer «konto → kontaktoppslag → direkte-samtale → broadcast».
  - Frontend: Integrasjonstest av `ChatViewModel` for lykkestien (send og motta melding).
- **Manuell validering**: To klienter ser meldinger innen <1 sekund, forblir innlogget etter restart, og kan logge ut/inn igjen.
- **Dokumentasjon**: Oppdater relevante dokumenter (f.eks. `PLAN.md`) med ny flyt og testoppsett slik at neste person kan kjøre demoen uten ekstra kontekst.

## Anbefalte neste steg
1. Implementer backend-endringene (session-respons, profilnavn, endepunkter) og legg til tester.
2. Oppdater frontend-onboarding og navigasjon til å bruke de nye API-ene, og test chat-flyten ende-til-ende.
