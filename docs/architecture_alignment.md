# Architecture alignment audit

Denne notaten dokumenterer siste gjennomgang av kodebasens arkitekturvalg og
hvordan dagens mapper/konfigurasjon matcher prinsippene i
[`architecture.md`](../architecture.md) og migreringsplanen i
[`IMPROVE_ARCHITECTURE.md`](../IMPROVE_ARCHITECTURE.md).

## Phoenix-umbrellaen

| Retningslinje | Observasjon |
| --- | --- |
| Bounded contexts forblir separate og kapslet | `apps/msgr/lib/msgr/` er fremdeles delt i `accounts`, `auth`, `bridges`, `chat`, `media`, `noise`, `transport` osv., slik at domenelogikk ikke lekker mellom kontekstene uten eksplisitte grensesnitt. |
| HTTP og realtime skilles | `apps/msgr_web/lib/msgr_web/` organiserer controllers, plugs, channels og LiveView-komponenter i egne mapper, mens selve domenelogikken ligger i `apps/msgr/`. |
| Noise og TLS skal kunne toggles uten kodeendringer | `config/runtime.exs` leser `MSGR_TLS_*` og `NOISE_*`-variabler for å starte HTTPS/Noise når de er aktivert, og `docker-compose.yml` eksponerer de samme bryterne via `.env`. |
| Én Postgres per miljø | Compose-filen definerer kun én `postgres:15`-tjeneste (`db`) som hele umbrellaen bruker i dev/test. |

## Flutter-klienten

| Retningslinje | Observasjon |
| --- | --- |
| Feature-first struktur | `flutter_frontend/lib/features/` inneholder `auth`, `bridges`, `chat`, `contacts`; delte tjenester/Redux ligger fortsatt i `lib/services` og `lib/redux`, slik at den modulære migreringen kan fullføres gradvis. |
| Shared kjernefunksjoner i `libmsgr` | `packages/libmsgr` og `packages/libmsgr_core` isolerer krypto, registrering og CLI-flyt slik at Flutter-UI kan bytte ut presentasjonslag uten å duplisere protokollkode. |
| Støtte for alternative UI-flater | Separate entrypoints (`main.dart`, `main_mobile.dart`, `main_desktop.dart`) under `flutter_frontend/lib/` aktiverer plattformspesifikk bootstrap slik migreringsplanen beskriver. |

## Integrasjonsbeslutninger (Noise + Flutter)

- `libmsgr_core` håndterer nå Noise-handshake automatisk før OTP-flowen og sender
  `noise_session_id`/`noise_signature` videre til `/api/auth/verify`, slik at
  CLI- og Flutter-integrasjonene tilfredsstiller kravet om Noise-transport.
- Backend tester (`messngr/noise/dev_handshake_test.exs`) validerer at
  `Messngr.Noise.DevHandshake` kun lykkes når transport og nøkler er aktivert,
  og at sesjonen virkelig blir persistert i registriet.

## Operasjonell sjekkliste

1. TLS kan toggles via miljøvariabler (`MSGR_TLS_*`) uten kodeendring.
2. Noise-transporten aktiveres/deaktiveres via `NOISE_TRANSPORT_ENABLED` +
   statisk nøkkel fra `.env` eller Secrets Manager.
3. Kun én Postgres-kilde i docker-stacken; andre tjenester bruker den via
   `POSTGRES_HOST=db`.
4. Flutter-klientens feature-mapper matcher den planlagte modulariseringen, og
   `libmsgr_core` holder protokollene isolert.
