# Chat-klient MVP – leveranseplan

Denne planen dekker hva som må være på plass for å lansere en første versjon av msgr som lar nye brukere registrere seg, logge inn, legge til venner og kommunisere én-til-én eller i team. Punktlisten fungerer som en sjekkliste med anbefalt prioritet (øverst først) og underpunkter der det er naturlig.

## Grunnleggende identitet og tilgang
- [ ] Registreringsflyt for nye brukere
  - [ ] OTP/OIDC-baserte utfordringer med rate-limiting og misbruksvern
  - [ ] Profilopprettelse (visningsnavn, avatar-placeholder, tidsstempling)
- [ ] Innlogging og økthåndtering
  - [ ] Stabile refresh tokens + automatisk reautentisering på klient
  - [ ] Enhetsregistrering med Noise-/JWT-nøkkelrotasjon og policy for revokering
- [ ] Konto- og profilinnstillinger
  - [ ] Endre display-navn, avatar og tilknyttede identiteter
  - [ ] Personvernvalg (tilgjengelighet via e-post/telefon, blokkeringer)

## Venner og kontaktadministrasjon
- [ ] Kontaktimport og matching mot eksisterende brukere
  - [ ] Klientside UI for søk/invitasjon og status (venter/akseptert)
  - [ ] Backend-API for pending/incoming forespørsler med varsling
- [ ] To-veis vennskapsmodell
  - [ ] Godkjenning/avslag, blokkering og oppheving
  - [ ] Listevisning med segmentering (favoritter, nylige)
- [ ] Varslinger for kontaktendringer
  - [ ] Push/badge-hendelser på mobil/web
  - [ ] In-app feed for aksepterte forespørsler

## Meldingsleveranse én-til-én
- [ ] Realtidskanal med pålitelig fallback
  - [ ] WebSocket med presence/typing og http-basert fallback for send/receive
  - [ ] Leveringskvitteringer (sendt, levert, lest) med timeline-oppdatering
- [ ] Meldingsopplevelse i klient
  - [ ] Rik tekst, emoji, grunnleggende fil-/bildestøtte og tilhørende opplasting
  - [ ] Logikk for kladd, retry, og visning av feilede sendinger
- [ ] Serverlagring og historikk
  - [ ] Cursor-baserte API-er for tidslinje og søk
  - [ ] Retensjon- og krypteringspolicy med backup/restore-prosedyre

## Teams og flerpersonssamtaler
- [ ] Teamopprettelse med typer (familie, jobb, interesse, prosjekt)
  - [ ] Tilpassede metadata pr. type (farger, ikon, default-roller)
  - [ ] Invitere via lenker/venn-lister + moderasjonsregler
- [ ] Kanaler og gruppesamtaler i team
  - [ ] Standardkanal ved oppstart + mulighet for private kanaler
  - [ ] Rollenivåer (eier, admin, medlem) og rettigheter (inviter, kaste ut, endre info)
- [ ] Team-oversikt i klient
  - [ ] Hurtigbytte mellom team, kanal-lister og uleste tellere
  - [ ] Varslinger per team/kanal (push + in-app badges)

## Tverrplattform-klient
- [ ] Onboarding-opplevelse i Flutter
  - [ ] Registrer/logg-inn, kontakt- og team-setup guide
  - [ ] Feilhåndtering, tomtilstander og tilgjengelighet (a11y) for hovedflyter
- [ ] Chat UI-paritet mobil/desktop
  - [ ] Responsive layouter for kanalliste, samtale og composer
  - [ ] Offline-modus med cache og sync når forbindelse gjenopprettes
- [ ] Varslingssystem
  - [ ] Push-integrasjon (Firebase/APNs) + lokal varsling på desktop/web
  - [ ] Preferanser per kanal/venn med synkronisering mot backend

## Drift, sikkerhet og kvalitet
- [ ] Infrastruktur for produksjonsmiljø
  - [ ] CI/CD pipelines med bygg, tester, migrasjoner og rullerende deploy
  - [ ] Overvåkning (metrics, logs, tracing) og alarmgrenser for kritiske tjenester
- [ ] Sikkerhetsgrunnmur
  - [ ] Policy for passordløse pålogginger, rate limiting og misbrukssporing
  - [ ] Juridiske krav (GDPR: data-eksport, sletting, samtykke)
- [ ] Kvalitetssikring og support
  - [ ] Integrasjonstester for registrering, vennskap, én-til-én- og gruppesamtaler
  - [ ] Supportverktøy (admin dashboard for manuell unlock, abuse reports)

## Milepæler og lanseringskriterier
- [ ] Alpha (intern)
  - [ ] Kjerneregistrering + én-til-én meldinger fungerer uten kritiske feil i 1 uke
  - [ ] Teamopprettelse mulig, men begrenset til interne brukere
- [ ] Beta (begrenset ekstern)
  - [ ] Vennestrømmen stabil, varslinger fungerer, grunnleggende analytics
  - [ ] Supportberedskap (FAQ, eskaleringsrutiner) og logging av kundefeil
- [ ] MVP launch
  - [ ] SLA-definerte responstider for meldingsleveranse og autentisering
  - [ ] Dokumentasjon (brukerveiledning + tekniske driftsrutiner) publisert
