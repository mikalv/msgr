# Plan for Slack-kvalitets message composer

## 1. Visjon og suksesskriterier
- Bekreft at composeren er et kjerneområde i produktstrategien, jamfør fokus på "awesome tekstfelt" og sendeflyt i Chat-MVP-målet i [PLAN.md](../PLAN.md).
- Fastsett P0-metrikker:
  - 0 % tapte utkast ved klientkrasj.
  - <200 ms P95 input-latens.
  - <500 ms P95 send→levering.
  - <0,1 % feil ved innsending (f.eks. API-feil).
- Definer funksjonsparitet mot Slack:
  - Multi-line rik tekst.
  - Inline formatering og kommandopalett.
  - @mentions.
  - Filopplastning med forhåndsvisning.
  - Emoji og reaksjoner.
  - Taleopptak.
  - Sikre utkast.

## 2. Nåværende fundament
- Flutter-composeren støtter allerede emoji-bytte, filvedlegg, tastatursnarveier (Ctrl/Cmd+Enter m.m.), slash-kommandoer, taleopptak og fleksibel layout over skjermstørrelser (ref. [frontend_responsive.md](./frontend_responsive.md)).
- Widgettester dekker sending, emoji-innsetting, slash-kommando-navigasjon, vedleggshåndtering og taleopptak.
- View-modellen persisterer tråddata og tekstutkast lokalt, og rehydreres ved offline-situasjoner for å forhindre datatap.
- Dokumentasjonen beskriver allerede responsive brytepunkter og at chat-komposeren skal skalere handlinger mellom mobil og desktop (se også [architecture.md](../architecture.md)).

## 3. Faseplan
### Fase A – Research & opplevelseskartlegging (uke 1–2)
- Gjennomfør funksjonsrevisjon av Slack composer (web/desktop) for å liste opp flows, mikrointeraksjoner og tilhørende states.
- Intervju interne brukere for pain points med eksisterende composer og forventninger til pålitelighet.
- Kartlegg tekniske gap: rik tekst, formatert forhåndsvisning, link-unfurling, multi-utkast, tråd-svar, tasks.
- Oppdater designbrief med states (default, skriving, vedlegg, feilsituasjon, offline) og definér UX-prinsipper.

### Fase B – Robusthet og driftssikkerhet (uke 2–4)
- Harden autosave: skriv end-to-end tester for krasj/refresh-scenarier og valider at `_cache.saveDraft` dekker flere samtidige tråder.
- Legg inn pessimistic UI states (sending, retry) i composerens controller og UI, og design fallback for API-feil og offline-modus.
- Implementer periodic background sync av drafts/attachments (med konfliktoppløsning).
- Gjør performance-profilering; optimaliser rebuilds og input-lag ved å splitte `ChatComposer` i mikrowidgets eller `InheritedNotifier`.
- Innfør focus- og accessibility-tests: skjermleserbaner, tastaturnavigasjon, high-contrast theme.

### Fase C – Funksjonsparitet og opplevelse (uke 4–8)
- Bygg rik tekst-editor med inline toolbar (bold, italics, lenker, code-blocks) og tastatursnarveier; sørg for rent Markdown/HTML-output.
- Implementer blokkelementer (sitater, lister) og multi-line resizing med drag-handle.
- Utvid slash-kommandoer med søk, kategorier og suggestion API; synkroniser med backend og legg inn permission checks.
- Legg til @mentions med autocomplete, emoji reaction shortcuts og support for sitering av meldinger.
- Forhåndsvisning av filer, bilder, video og lenker (inkl. upload progress, cancel, retry). Integrer med eksisterende `ChatMediaAttachment`.
- Voice note-polish: waveform-visualisering, noise cancellation toggles, transkripsjon (langsiktig).

### Fase D – Observability, kvalitet og samsvar (uke 6–10)
- Instrumenter metrics: input latency, autosave success rate, send failure rate, typing indicator accuracy; send til dashboard som definert i [PLAN.md](../PLAN.md).
- Utvid testdekning: legg til widget/e2e-tester for nye flows (rich text, mentions, error states), og snapshot/regresjonstester for layout.
- Legg inn kontraktstester mellom frontend og backend for slash-kommandoer og opplasting.
- Gjør kaostester: simuler offline, nettverksflapping, API-timeouts, og valider at composer holder utkastet og informerer brukeren.
- Sett opp kvalitetsgate i CI: `flutter analyze`, `flutter test`, samt visuell regresjon for composer.

### Fase E – Utrulling og kontinuerlig forbedring (uke 10–12)
- Feature-flag composer v2 bak remote config for gradvis utrulling (intern → pilot → GA).
- Etabler feedback-loop i app (internt dogfood) og i supportkanaler.
- Dokumenter nye flows i hjelpesenter, release notes og intern onboarding.
- Retrospektiv: mål opp mot suksessmetrikker, prioriter videre forbedringer (f.eks. AI-svarutkast, templates).

## 4. Leveranser og avhengigheter
- Designsystem-komponenter for rik tekst og toolbars.
- Oppdatert API for slash-kommandoer, mentions og opplasting.
- Observability-pipelines og dashboards.
- QA-plan med automatiserte og manuelle sjekklister.

## 5. Milepæler
- Uke 2: Ferdig research og detaljert designbrief.
- Uke 4: Stabil autosave/offline-håndtering, grunnleggende observability.
- Uke 8: Rik tekst, mentions, forbedret attachments; interne piloter.
- Uke 10: Full testdekning, observability live, forberedt utrulling.
- Uke 12: GA med dokumentasjon, målrapport og backlog for iterasjoner.
