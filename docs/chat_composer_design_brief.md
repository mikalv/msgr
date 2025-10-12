# Chat composer designbrief

## 1. Formål
- Sikre en pålitelig, Slack-paritet chat composer med tydelige stater, feedback og tilgjengelighet.
- Bygge videre på innsikten fra research-intervjuer og Slack-funksjonsinventaret dokumentert i `Research.md`.

## 2. Kjernestater
| State | Beskrivelse | Primær feedback | Observability |
| --- | --- | --- | --- |
| Default | Tomt felt, emoji-/vedleggsikoner synlige | Hinttekst "Del en oppdatering…" | `composer_idle` |
| Skriving | Tekstfelt aktivt, formatverktøy vises | Autosave-status viser "Endringer ikke lagret ennå" | `composer_draft_dirty` |
| Sending | Sendknapp spinner, input disabled | Banner ved behov, autosave settes til "lagrer" | `composer_send_attempt` + latency |
| Feil | Banner med ikon + handling (retry) | Rød bakgrunn, CTA "Prøv igjen" | `composer_send_failure` |
| Offline kø | Informasjonsbanner m. sky-ikon | Tekst "Melding lagret offline" | `composer_send_offline` |

## 3. Interaksjoner
- **Autosave**: Snapshot av tekst, vedlegg og stemmeopptak lagres ved tastetrykk og flushes <600 ms etter siste endring. Feil status kommuniseres i statuslinje og via Telemetry.
- **Retry**: Ved sendefeil vises banner med "Prøv igjen" som trigger `onSubmit` med eksisterende draft.
- **Vedlegg**: Drag & drop og filvelger deaktivert mens sending pågår for å unngå state-konflikt.
- **Voice**: Recorder-knapp følger busy-state; stoppfunksjon alltid tilgjengelig.

## 4. Tilgjengelighet og fokusrekkefølge
1. Emoji
2. Vedlegg
3. Kamera
4. Tekstfelt
5. Voice (toggle / stop)
6. Send

- Fokus reetableres på tekstfelt etter send.
- `Semantics` live-region brukes for autosave-status slik at skjermlesere plukker opp endringer.
- Send-knapp annonseres som "Send melding" / "Sender melding" avhengig av state.

## 5. Feil- og tomtilfeller
- **Autosave failure**: Statuslinje i rødt med tekst "Kunne ikke lagre utkast". Logger via `composer_autosave_failure`.
- **Upload blokkert offline**: Banner med sky-ikon og tekst "Ingen nettverkstilkobling – kan ikke laste opp media.".
- **Command-only**: Vis systemmelding som kvittering (`/command` registrert) selv uten tekst.

## 6. Observability og QA
- Logg autosave success/failure, send-latens og offline kø i eksisterende dashboards.
- Widgettester dekker autosave-status, retry-banner og fokusrekkefølge.
- Manuelle QA-sjekkpunkter: tastaturnavigasjon, high-contrast modus (WCAG AA), offline send+refresh.

## 7. Åpne punkter
- Performance-profilering av rebuilds ved lange tråder (fase B).
- Forhåndsvisning av lenker og flere samtidige utkast (fase C).
- Visuell regresjonstesting for store layout-endringer før GA.
