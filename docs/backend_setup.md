# Backend-oppsett

Denne notaten beskriver de viktigste bryterne og API-ene som trengs for å
kjøre msgr-backenden lokalt, spesielt rundt Noise-handshake og kontoendepunkter
som brukes av OTP-flyten.

## Noise-dev-handshake

- Dev-handshaken styres av `config :msgr, Messngr.Noise.DevHandshake`.
  - I `dev.exs` er den aktivert med `allow_without_transport: true` slik at
    `/api/noise/handshake` kan brukes selv om selve Noise-transporten er
    deaktivert.
  - I `test.exs` er togglen aktivert, men `allow_without_transport` er `false`
    slik at tester kan eksplisitt verifisere både lykkede og feilede kall.
- `config/runtime.exs` leser to miljøvariabler slik at deployment kan overstyre
  dev-standardene:
  - `NOISE_DEV_HANDSHAKE_ENABLED`
  - `NOISE_DEV_HANDSHAKE_ALLOW_DISABLED`
- Når dev-handshaken er deaktivert eller Noise-transporten er slått av uten at
  `allow_without_transport` er satt, svarer controlleren med `404`/`503` slik at
  klientene tydelig får vite at stubben ikke er tilgjengelig.

## Autorisasjon med Noise-token

Alle samtaleendepunkter (bl.a. `POST /api/conversations`) går nå gjennom
`MessngrWeb.Plugs.CurrentActor` med `authorization_schemes: [:noise]`. Det betyr
at `Authorization: Noise <token>` eller `x-noise-session` må være satt; gamle
`Bearer`-tokens blir blankt avvist med `401`.

Testhjelperen `attach_noise_session/3` i `ConnCase` setter riktig header når du
skriver controller-tester.

## Kontoendepunkter

- OTP-responsen fra `/api/auth/verify` inkluderer nå `profile_id` og en
  `profile`-payload slik at klienten vet hvilken profil som ble logget inn.
- Standard profilnavn arver fornavnet fra `display_name` (eller e-postens
  lokal-del) i stedet for det generiske «Privat».
- `GET /api/account/me` (i API-scope med Noise-token) returnerer den samme
  kontostrukturen som `AccountController.show/2`, slik at klienter kan hente
  gjeldende konto uten å gå via admin-endepunktene i `/api/users`.

## Kjøre backend

1. `cd backend && mix deps.get`
2. `MIX_ENV=dev mix ecto.setup`
3. `mix phx.server`

I dev kan du deretter generere en midlertidig Noise-handshake med
`curl -X POST http://localhost:4000/api/noise/handshake` før du starter OTP-flowen.

## Scripts og hurtigkommandoer

For å kutte ned på copy/paste av lange kommandoer finnes det nå to hjelpeskript i
repoet:

- `./scripts/start_stack.sh [-d]` setter `NOISE_TRANSPORT_ENABLED=true` og kjører
  `docker compose up` med samme `docker-compose.yml` som integrasjonstestene.
  Legg til `-d` for å kjøre i bakgrunnen.
- `./scripts/run_flutter.sh [host] [flutter-argumenter]` kjører `flutter pub get`
  i `flutter_frontend/` og starter klienten med
  `--dart-define=MSGR_BACKEND_HOST=<host>`. Host kan settes via første argument
  eller miljøvariabelen `MSGR_BACKEND_HOST` (standard er
  `auth.7f000001.nip.io`). Alle ekstra argumenter sendes videre til
  `flutter run`.

## Manuell validering

Når stacken kjører er demoflyten vi bruker internt:

1. `./scripts/start_stack.sh -d` for å starte backend (StoneMQ, auth, API). Vent
   til `auth.7f000001.nip.io` svarer.
2. `cd flutter_frontend/packages/libmsgr_cli && dart run bin/msgr.dart integration-flow --json`
   for å provisionere bruker, team og få ut `teamHost`/tokens.
3. `MSGR_BACKEND_HOST=<teamHost> ./scripts/run_flutter.sh` for å starte appen mot
   riktig subdomene.
4. Send en melding i en ny eller eksisterende kanal og bekreft at den dukker opp
   under ett sekund – backend svarer med `message_created` over sokkel og UI
   viser bekreftelsen.
5. Logg ut fra klienten, logg inn igjen med samme OTP og bekreft at tidligere
   samtaler/rom lastes inn uten feil.

Denne runden dokumenterer både at sokkeleventy bekreftes raskt («send→ack») og at
re-login beholder lagrede nøkler/device context.
