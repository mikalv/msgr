# Frontend-chatflyt

Denne dokumentasjonen oppsummerer den nye OTP-baserte innloggingsflyten og
chatopplevelsen i Flutter-klienten.

## Innlogging og backend-override

1. **DevLoginPage** gir nå tre felt: visningsnavn, valgfri e-postadresse og et
   backend-host-felt. Host-feltet brukes til å kalle
   `BackendEnvironment.instance.override(...)` slik at man kan peke klienten mot
   en alternativ backend uten å bygge appen på nytt. Feltet aksepterer både rene
   hostnavn som `10.0.2.2:4000` og komplette URI-er.
2. Når brukeren sender inn skjemaet opprettes først en Noise-handshake via
   `AuthApi.createDevHandshake()` før OTP-kode blir sendt. Etter at koden er
   verifisert lagres `AccountIdentity` samt Noise-token, Noise-session-ID og
   nøklene lokalt via `AuthIdentityStore`.
3. `AuthGate` rehydrerer identiteten på oppstart og eksponerer
   `AuthSession` til resten av applikasjonen.

## Navigasjon uten workspace

`AppNavigation.redirectWhenLoggedIn` har blitt forenklet til å sende brukeren
rett til dashboardet så snart en profil er autentisert. Kravet om å velge et
workspace først er fjernet slik at direktechat fungerer med bare en profil.

## Chat-arkitektur

- `ChatViewModel` er ansvarlig for å laste kanaler, meldinger og å knytte seg til
  sanntidsstrømmen.
- Realtime-klienten (`ChatSocket`) emiterer nå `ChatConnectionEvent` for
  tilkobling, frakobling og forsøk på gjenoppkobling. View-modellen oppdaterer
  `isRealtimeConnected` basert på disse hendelsene og faller automatisk tilbake
  til REST-kall når sokkelen er nede.
- Widgets som `ChatTimeline`, `ChatComposer` og `TypingIndicator` bruker
  view-modellen via `Provider`.
- Chat API-klientene (`ChatApi`, `ContactApi`) gir funksjoner som
  `ensureDirectConversation` og `lookupKnownContacts` for å starte direktechatter
  og slå opp profiler basert på kontaktinformasjon.

## Testing

- `AuthIdentityStore` har enhetstester som verifiserer at Noise-tokens og nøkler
  lagres lokalt og fjernes ved utlogging.
- `ChatViewModel` har widgettester som dekker både sanntidshendelser og
  kommandoer (reaksjoner, pinning, typing) inkludert håndtering av nye
  tilkoblingshendelser.
