# Plan for Slack-kvalitets message composer

## Sammendrag
- **Målbildet** er en pålitelig, rik tekst-komposer som leverer Slack-paritet og støtter Chat-MVP-strategien fra [PLAN.md](../PLAN.md).
- **Fasene** dekker research, robusthet, funksjonsparitet, observability og utrulling med tydelige milepæler og ansvarspunkter.
- **Suksessmetrikker** inkluderer null tapte utkast, <200 ms P95 input-latens og <0,1 % feil ved innsending, målt via instrumentering definert i [PLAN.md](../PLAN.md) og observability-oppsettet i [architecture.md](../architecture.md).
- **Leveranser** spenner fra rik tekst-komponenter i designsystemet til CI-gater, dokumentasjon og kvalitetsrutiner.

## 1. Visjon og suksesskriterier
- Bekreft at composeren er et kjerneområde i produktstrategien, jamfør fokus på "awesome tekstfelt" og sendeflyt i Chat-MVP-målet i [PLAN.md](../PLAN.md).
- Fastsett P0-metrikker:
  - 0 % tapte utkast ved klientkrasj.
  - <200 ms P95 input-latens.
  - <500 ms P95 send→levering.
  - <0,1 % feil ved innsending (f.eks. API-feil).
- Definer funksjonsparitet mot Slack:
  - Multi-line rik tekst med inline formatering, kommandopalett og blokkelementer.
  - @mentions og emoji/reaksjoner i composer.
  - Filopplastning med forhåndsvisning, upload progress og retry.
  - Taleopptak med waveform-visualisering og sikre utkast.
- Kartlegg sekundære metrikker (NPS på compose-opplevelse, support-ticket-volum, adoption av nye features) for å justere prioritering i fase D og E.

## 2. Nåværende fundament
- Flutter-composeren støtter allerede emoji-bytte, filvedlegg, tastatursnarveier (Ctrl/Cmd+Enter m.m.), slash-kommandoer, taleopptak og fleksibel layout over skjermstørrelser (ref. [frontend_responsive.md](./frontend_responsive.md)).
- Widgettester dekker sending, emoji-innsetting, slash-kommando-navigasjon, vedleggshåndtering og taleopptak.
- View-modellen persisterer tråddata og tekstutkast lokalt, og rehydreres ved offline-situasjoner for å forhindre datatap.
- Dokumentasjonen beskriver responsive brytepunkter og at chat-komposeren skal skalere handlinger mellom mobil og desktop (se [architecture.md](../architecture.md) og [Research.md](../Research.md) for innsikt om brukerbehov).
- Infrastruktur for observability er initiert i backend/dokker-oppsett; composer-metrikker må kobles på samme dashboards.

## 3. Faseoversikt

| Fase | Uker | Fokus | Hovedleveranser |
| --- | --- | --- | --- |
| A | 1–2 | Research & opplevelseskartlegging | Funksjonsinventar, brukerintervjuer, oppdatert designbrief |
| B | 2–4 | Robusthet & driftssikkerhet | Autosave E2E, pessimistic UI, background sync, A11y-plan |
| C | 4–8 | Funksjonsparitet | Rik tekst-editor, utvidede kommandoer, mentions, forbedret attachments |
| D | 6–10 | Observability & kvalitet | Instrumentering, testutvidelse, kontraktstester, kaostester |
| E | 10–12 | Utrulling & forbedring | Feature flagging, feedback-loop, dokumentasjon, retrospektiv |

## 4. Faseplan med detaljerte aktiviteter
### Fase A – Research & opplevelseskartlegging (uke 1–2)
* [x] - Gjennomfør funksjonsrevisjon av Slack composer (web/desktop) for å liste opp flows, mikrointeraksjoner og tilhørende states.
* [x] - Intervju interne brukere for pain points med eksisterende composer og forventninger til pålitelighet.
* [x] - Kartlegg tekniske gap: rik tekst, formatert forhåndsvisning, link-unfurling, multi-utkast, trådsvar, tasks og interaksjon med `ChatMediaAttachment`.
* [x] - Oppdater designbrief med states (default, skriving, vedlegg, feilsituasjon, offline) og definér UX-prinsipper.
* [x] - Dokumenter funn og anbefalinger i en utvidelse av [Research.md](../Research.md) for å sikre sporbarhet.

### Fase B – Robusthet og driftssikkerhet (uke 2–4)
* [x] - Harden autosave: skriv end-to-end tester for krasj/refresh-scenarier og valider at `_cache.saveDraft` dekker flere samtidige tråder.
* [x] - Legg inn pessimistic UI states (sending, retry) i composerens controller og UI, og design fallback for API-feil og offline-modus.
* [x] - Implementer periodic background sync av drafts/attachments (med konfliktoppløsning) og loggfør status i observability-pipelines.
* [ ] - Gjør performance-profilering; optimaliser rebuilds og input-lag ved å splitte `ChatComposer` i mikrowidgets eller `InheritedNotifier`.
* [x] - Innfør focus- og accessibility-tests: skjermleserbaner, tastaturnavigasjon, high-contrast theme og kontrastkrav i designsystemet.

### Fase C – Funksjonsparitet og opplevelse (uke 4–8)
* [ ] - Bygg rik tekst-editor med inline toolbar (bold, italics, lenker, code-blocks) og tastatursnarveier; sørg for rent Markdown/HTML-output og kompatibilitet med `msgr_messages`.
  * [x] - Lenkeformatering med dialog og Markdown-output i composerens verktøylinje.
* [ ] - Implementer blokkelementer (sitater, lister) og multi-line resizing med drag-handle som følger responsive prinsipper fra [frontend_responsive.md](./frontend_responsive.md).
  * [x] - Drag-handle for høydejustering av meldingsfeltet med tastaturnavigasjon og semantikk.
- Utvid slash-kommandoer med søk, kategorier og suggestion API; synkroniser med backend og legg inn permission checks.
- Legg til @mentions med autocomplete, emoji reaction shortcuts og support for sitering av meldinger.
- Forhåndsvisning av filer, bilder, video og lenker (inkl. upload progress, cancel, retry). Integrer med eksisterende `ChatMediaAttachment` og valider med widget/e2e-tester.
- Voice note-polish: waveform-visualisering, noise cancellation toggles, transkripsjon (langsiktig) og fallback for enheter uten mikrofon.

### Fase D – Observability, kvalitet og samsvar (uke 6–10)
- Instrumenter metrics: input latency, autosave success rate, send failure rate, typing indicator accuracy; send til dashboard som definert i [PLAN.md](../PLAN.md).
- Utvid testdekning: legg til widget/e2e-tester for nye flows (rich text, mentions, error states), snapshot/regresjonstester for layout, og kontraktstester mellom frontend/backend.
- Gjør kaostester: simuler offline, nettverksflapping, API-timeouts, og valider at composer holder utkastet og informerer brukeren.
- Sett opp kvalitetsgate i CI: `flutter analyze`, `flutter test`, visuell regresjon for composer og kontraktstester i backend.
- Formaliser supportprosesser for bug-triage og rollback-planer.

### Fase E – Utrulling og kontinuerlig forbedring (uke 10–12)
- Feature-flag composer v2 bak remote config for gradvis utrulling (intern → pilot → GA) og definer kriterier for hver bølge.
- Etabler feedback-loop i app (internt dogfood) og i supportkanaler, med ukentlige innsjekker i produktmøtet.
- Dokumenter nye flows i hjelpesenter, release notes og intern onboarding, og koble til produktivitetsveikartet i [IMPROVE_ARCHITECTURE.md](../IMPROVE_ARCHITECTURE.md).
- Retrospektiv: mål opp mot suksessmetrikker, prioriter videre forbedringer (f.eks. AI-svarutkast, templates) og legg oppfølgingsoppgaver i backloggen.

## 5. Leveranser og avhengigheter
- Designsystem-komponenter for rik tekst og toolbars.
- Oppdatert API for slash-kommandoer, mentions og opplasting.
- Observability-pipelines, dashboards og alarmer koblet til eksisterende driftspålegg.
- QA-plan med automatiserte og manuelle sjekklister.
- Oppdatert dokumentasjon (arkitektur, research, hjelpesenter) med composer-spesifikke kapitler.
- Kapasitet fra backend for å støtte advanced attachments, mentions og command-permissions.

## 6. Kickoff-sjekkliste (uke 0)
1. Bekreft prosjektteam, eierskap og kommunikasjonskanaler.
2. Opprett Jira/Linear-epics for hver fase og importer aktiviteter fra denne planen.
3. Sett opp måleplan i observability-verktøy (dashboards, alarmer) i tråd med [architecture.md](../architecture.md).
4. Planlegg research-intervjuer og alloker design/UX-ressurser.
5. Revider eksisterende tester og byggpipelines for å sikre at `flutter analyze` og `flutter test` er grønne før fase B starter.
6. Varsle interessenter i produktforum og dokumenter kickoff i CHANGELOG.

## 7. Risikoer og avbøtende tiltak
- **Rik tekst-kompleksitet**: Kan forsinke fase C.
  - *Tiltak*: Etabler MVP-scope, vurdér tredjeparts editor-komponenter, spike i uke 2.
- **Performance-regresjoner**: Nye features kan øke input-lag.
  - *Tiltak*: Sett opp profileringsbudsjett og automatiserte latency-tester i CI.
- **Backend-avhengigheter**: Slash-kommandoer og mentions krever API-utvidelser.
  - *Tiltak*: Planlegg backend-roadmap parallelt og bruk kontraktstester i fase D.
- **Brukeradopsjon**: Nye flows kan være ukjente for eksisterende brukere.
  - *Tiltak*: Bygg onboarding-hints, tooltipper og release notes; overvåk support.

## 8. Milepæler
- **Uke 2**: Ferdig research og detaljert designbrief.
- **Uke 4**: Stabil autosave/offline-håndtering, grunnleggende observability.
- **Uke 8**: Rik tekst, mentions, forbedret attachments; interne piloter.
- **Uke 10**: Full testdekning, observability live, forberedt utrulling.
- **Uke 12**: GA med dokumentasjon, målrapport og backlog for iterasjoner.
