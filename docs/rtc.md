# Realtime media signalling

Dette dokumentet beskriver WebRTC-signalisering i Messngr for 1:1 (og
gruppe-klare) stemme-/video-samtaler.

## Oversikt

* **Signalisering:** Phoenix-kanalen `rtc:*` i `MessngrWeb.RTCChannel` bruker
  in-memory `CallRegistry` for aktive samtaler.
* **State:** Registry oppretter en `CallSession` per samtale (deltakere,
  media-typer, metadata).
* **Kalltyper:** Samme stakk støtter gruppe- og 1–1-samtaler. Direkte kall
  (`:direct`) begrenses til vert + én deltaker.
* **Klient:** Flutter bruker `flutter_webrtc` med `CallProvider` (Riverpod) og
  call UI under `packages/core/lib/ui/call/` / `call_screen/`. Design og
  implementasjonsplan: `docs/plans/2026-03-28-webrtc-calls-design.md` og
  `docs/plans/2026-03-28-webrtc-implementation.md`.
* **TURN:** `GET /api/turn-credentials` (`TurnController`) utsteder ephemeral
  credentials. Docker Compose kjører `coturn` for lokal STUN/TURN.

## Meldingsflyt

1. Initiativtaker kobler seg til `rtc:<conversation_id>` med `profile_id` og
   ønskede media-typer.
2. Serveren oppretter en ny `CallSession` hvis ingen pågående samtale finnes og
   svarer med `call_id` og eksisterende deltakere.
3. Påfølgende deltakere må sende `call_id` i `join`-payload. Serveren legger dem
   til i registreret og kringkaster SDP/ICE-meldinger videre til andre
   deltakere.
4. Når verten forlater samtalen eller siste deltaker kobler av, avsluttes
   `CallSession`.

## Videre arbeid

* Persistente kall for historikk, logging og analyser.
* Ende-til-ende kryptering av mediestrømmer (utenom transport-TLS/TURN).
* Strammere policy-sjekker mot profiler/team-modus der det mangler.
* Prod TURN/ICE-konfigurasjon (host, secret, TTL) utenom compose-defaults.
* Web-klient: `CallProvider` hopper over WebRTC på web i dag
  (`kIsWeb` early-return) — trenger egen håndtering.
