# Realtime media signalling

Dette dokumentet beskriver første iterasjon av WebRTC-signalisering i Messngr.

## Oversikt

* **Signalisering:** Phoenix-kanalen `rtc:*` i `MessngrWeb.RTCChannel` bruker en in-memory `CallRegistry` for å holde orden på aktive samtaler.
* **State:** Registry oppretter en `CallSession` per samtale som holder styr på deltakere, ønskede media-typer og tilhørende metadata.
* **Distribusjon:** Signalisering lever i eksisterende backend-container. Docker Compose har fått en `coturn`-tjeneste for STUN/TURN i lokal utvikling.

## Meldingsflyt

1. Initiativtaker kobler seg til `rtc:<conversation_id>` med `profile_id` og ønskede media-typer.
2. Serveren oppretter en ny `CallSession` hvis ingen pågående samtale finnes og svarer med `call_id` og eksisterende deltakere.
3. Påfølgende deltakere må sende `call_id` i `join`-payload. Serveren legger dem til i registreret og kringkaster SDP/ICE-meldinger videre til andre deltakere.
4. Når verten forlater samtalen eller siste deltaker kobler av, avsluttes `CallSession`.

## Videre arbeid

* Persistente kall for historikk, logging og analyser.
* Integrasjon med ende-til-ende kryptering av mediestrømmer.
* Autentisering/autorisasjon mot profiler og tilhørende policies.
* Kobling mot egen TURN/ICE-konfigurasjon for prod.
