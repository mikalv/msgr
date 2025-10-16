# WebAuthn og IDP-innlogging

Denne planen beskriver hvordan Msgr skal støtte passkey-baserte WebAuthn-innlogginger og eksterne IDP-strømmer der brukeren fullfører autentisering i nettleser før appen får beskjed.

## Mål

1. Støtte native WebAuthn-passkeys i Flutter-klienten.
2. La backend orkestrere passkey-registrering og -innlogging via Noise/OAuth-endepunkt.
3. Håndtere IDP-redirect (Google, Azure AD m.fl.) der brukeren logger inn i ekstern nettleser.
4. Pushe «login fullført»-signal fra backend til appen uten at brukeren manuelt fornyer token.

## Arkitektur

### 1. Session Broker

* Opprett nytt backend-endepunkt `POST /api/auth/external/sessions` som utsteder en kortlivet `session_token` og metadata om forventet autentiseringsmetode (webauthn/idp).
* Lagre sessioner i en `external_login_sessions` tabell med status (`pending`, `approved`, `failed`) og opsjonelt `public_key_credential_request` payload for WebAuthn.
* Flutter initialiserer en `ExternalLoginSession` gjennom Auth store og starter WebAuthn- eller IDP-flyt basert på type.

### 2. WebAuthn-håndtering

* Backend bruker `webauthn_ex` (Elixir) til å generere `PublicKeyCredentialCreationOptions` for registrering og `...RequestOptions` for innlogging.
* Flutter bruker `corbado/flutter-passkeys` (se IDEAS) for å hente `AuthenticatorResponse` og poster til `POST /api/auth/external/webauthn/callback`.
* Callback validerer respons, oppdaterer session status til `approved` og utsteder Noise token + refresh token.

### 3. IDP-redirect

* Session broker returnerer `verification_uri` og `session_token`.
* Appen åpner nettleser med `verification_uri?session_token=...` for OAuth/OIDC.
* Etter vellykket IDP-login treffer redirect en ny `ExternalAuthController.callback/2` som validerer koden, knytter IDP-identitet til bruker og markerer session `approved`.

### 4. Server push til app

* Introducer et nytt Phoenix Channel (`external_sessions`) eller gjenbruk eksisterende socket med topic `external_session:<session_token>`.
* Når session status endres, broadcaster backend et `session_update` event med `status` og eventuelle tokens.
* Flutter abonnerer på topic umiddelbart etter at session er opprettet. Når `approved` mottas, lukker den nettleseren (hvis fortsatt åpen) og fullfører innlogging ved å lagre Noise/refresh tokens.
* For enheter uten websockets, fallback til `GET /api/auth/external/sessions/:token` polling hver 2. sekund.

### 5. Sikkerhet og UX

* Sessions utløper etter 5 minutter og blir automatisk `failed`.
* Push-event inkluderer `mfa_required` flagg hvis ytterligere steg kreves.
* Logging og metrikker: emit `external_login.session_created`, `...completed`, `...expired` for observability.

## Milepæler

1. **Discovery (aktiv)** – valider Flutter-passkey-APIer og bibliotekvalg, definér databaseoppsett.
2. **Prototype** – implementere session broker + websocket broadcast uten IDP/WAF hardening.
3. **Pilot** – støtte Google og Azure AD, skrive ende-til-ende tester.
4. **Generell tilgjengelighet** – dokumentasjon, feilhåndtering og fallback.

Status spyles inn i `IDEAS.md` (eksperimenttabellen) og `CHANGELOG.md` når milepæler beveger seg fremover.
