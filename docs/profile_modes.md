# Profilmoduser i Msgr

Denne oversikten beskriver hvordan de nye profilmodusene fungerer gjennom hele systemet.

## Begreper

- **Profil**: En identitet tilknyttet en konto. Kan ha modus `privat`, `work` eller `family`.
- **Tema**: Fargepreferanser som kontrollerer opplevd stil (primærfarge, bakgrunn, kontrast osv.).
- **Varslingspolicy**: Styrer hvordan enheten skal sende varsler (push/e-post/SMS, stille perioder, dempede etiketter).
- **Sikkerhetspolicy**: Definerer skjermlås, biometrikk og hvordan sensitive varsler vises.

## Scenarier

### Oppstart
1. Brukeren logger inn og velger team.
2. Klienten henter profiler via `/api/profiles` og lagrer aktive preferanser i Redux + lokal cache.
3. Første profil merket som `is_active` brukes til Noise-sesjon og chat.

### Bytte modus
1. Bruker trykker på profilchip i modus-veksleren.
2. Appen kaller `POST /api/profiles/:id/switch` via `ProfileApi`.
3. Serveren svarer med ny Noise-token og oppdatert profil.
4. Redux og `AuthIdentityStore` oppdateres, websocket sesjon bruker ny profil.
5. UI viser banneren for valgt modus og filtrerer innboksen.

### Innboksfiltre
- Filterchips (`Alle`, `Privat`, `Jobb`, `Familie`) styrer hvilke samtaler som vises.
- Filtreringen skjer ved å slå opp medlemmene i profillageret lokalt, slik at bare samtaler med ønsket modus vises.

### Preferanser
- Tema-, varslings- og sikkerhetspolicyer normaliseres på server og sendes til klient.
- Klienten persisterer preferansene lokalt for frakoblet støtte og videre synkronisering.

## Backendkontrakt

| Felt | Beskrivelse |
|------|-------------|
| `name` | Vises i UI-bannere og chips |
| `slug` | Teknisk identifikator/handle |
| `mode` | `private`, `work`, `family` |
| `theme` | Map med `mode`, `variant`, `primary`, `accent`, `background`, `contrast` |
| `notification_policy` | Map med push/e-post/SMS, dempede etiketter, `quiet_hours` |
| `security_policy` | PIN/Biometri/timeout/sensitive varsler |
| `is_active` | Marker aktiv profil for sesjonen |

## Videre arbeid
- Bruke tema-data direkte i chattemaer.
- Eksponere preferanser i egen innstillingsskjerm for hver profil.
- Synkronisere innstillingsendringer offline.
