# Architecture alignment audit

Denne notaten dokumenterer siste gjennomgang av kodebasens arkitekturvalg og
hvordan dagens mapper/konfigurasjon matcher prinsippene i
[`architecture.md`](../architecture.md) og migreringsplanen i
[`IMPROVE_ARCHITECTURE.md`](../IMPROVE_ARCHITECTURE.md).

## Phoenix-umbrellaen

| Retningslinje | Observasjon |
| --- | --- |
| Bounded contexts forblir separate og kapslet | `backend/apps/msgr/lib/msgr/` er delt i kataloger som `accounts`, `auth`, `bridges`, `chat`, `media`, `noise`, `share_links` og `transport`. Hvert område har sitt eget `*.ex`-entrypoint som eksponerer kontekst-API-er og holder domenelogikk isolert. |
| HTTP og realtime skilles | `backend/apps/msgr_web/lib/msgr_web/` organiserer controllers, channels, LiveComponents og plugs i egne mapper. `MessngrWeb.Router` binder alt sammen, mens domenelogikken fortsatt ligger i `apps/msgr`. |
| Noise og TLS skal kunne toggles uten kodeendringer | `backend/config/runtime.exs` leser `MSGR_TLS_*` og `NOISE_*`-variabler via `bool_env`/`port_env`-hjelpere (nå initialisert før bruk) slik at HTTPS/Noise startes når flaggene settes. `docker-compose.yml` og `.env.example` eksponerer de samme bryterne, så operatører trenger ikke kodeendringer. |
| Én Postgres per miljø | Compose-filen definerer kun én `postgres:15`-tjeneste (`services.db`). Alle backend-appene bruker den via `POSTGRES_HOST=db`, og ingen andre databaser er deklarert. |

## Flutter-klienten

| Retningslinje | Observasjon |
| --- | --- |
| Feature-first struktur | `flutter_frontend/lib/features/` inneholder dedikerte mapper for `auth`, `bridges`, `chat` og `contacts`, hver med `state`, `widgets`, `models` eller `services` som holder UI og logikk samlet per feature. Delte tjenester ligger i `lib/services`, mens global Redux ligger i `lib/redux`. |
| Shared kjernefunksjoner i `libmsgr` | `flutter_frontend/packages/libmsgr` og `flutter_frontend/packages/libmsgr_core` kapsler krypto, registrering og transportlag slik at Flutter-UI kan bytte presentasjonslag eller klient uten å duplisere protokollkode. |
| Støtte for alternative UI-flater | Separate entrypoints (`lib/main.dart`, `lib/main_mobile.dart`, `lib/main_desktop.dart`) håndterer plattformspesifikk bootstrap og lar oss variere UI-komposisjon uten å endre feature-mappene. |

## Integrasjonsbeslutninger (Noise + Flutter)

- `libmsgr_core` håndterer Noise-handshake automatisk før OTP-flowen og sender
  `noise_session_id`/`noise_signature` videre til `/api/auth/verify`, slik at
  CLI- og Flutter-integrasjonene tilfredsstiller kravet om Noise-transport.
- Backend tester (`messngr/noise/dev_handshake_test.exs`) validerer at
  `Messngr.Noise.DevHandshake` kun lykkes når transport og nøkler er aktivert,
  og at sesjonen virkelig blir persistert i registriet.

## Operasjonell sjekkliste

1. TLS kan toggles via miljøvariabler (`MSGR_TLS_*`) uten kodeendring – `.env.example`
   beskriver bryterne og `backend/config/runtime.exs` aktiverer HTTPS når de settes.
2. Noise-transporten aktiveres/deaktiveres via `NOISE_TRANSPORT_ENABLED` med
   statisk nøkkel fra miljøvariabel eller Secrets Manager, dokumentert i
   `.env.example` og `docker-compose.yml`.
3. Kun én Postgres-kilde i docker-stacken; andre tjenester bruker den via
   `POSTGRES_HOST=db`.
4. Flutter-klientens feature-mapper matcher den planlagte modulariseringen, og
   `libmsgr_core` holder protokollene isolert fra UI-laget.
