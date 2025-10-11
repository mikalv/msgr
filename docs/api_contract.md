# API-kontrakt for msgr

Denne siden dokumenterer forventet kontrakt mellom msgr-backend og Flutter-klienten. Alle responser er JSON-kodet og bruker snake_case i feltnavn med mindre annet er spesifisert.

## Autentisering og identitet

- HTTP-klienten identifiserer seg med to obligatoriske headere på alle samtalerelaterte kall:
  - `x-account-id`: UUID for kontoen som er aktiv i klienten.
  - `x-profile-id`: UUID for profilen som sender/leser meldinger.
- Backend verifiserer at profilen tilhører kontoen. Mismatch gir `401 Unauthorized`.
- WebSocket-tilkoblingen bruker de samme verdiene som join-parametre (se under).

## REST-endepunkter

### Opprette konto

`POST /api/users`

```json
{
  "display_name": "Kari Nordmann",
  "email": "kari@example.com"
}
```

**Respons 201**

```json
{
  "data": {
    "id": "acct-uuid",
    "display_name": "Kari Nordmann",
    "handle": "kari",
    "profiles": [
      {
        "id": "profile-uuid",
        "name": "Privat",
        "mode": "private"
      }
    ]
  }
}
```

### Opprette eller hente direktemelding

`POST /api/conversations`

```json
{
  "target_profile_id": "peer-profile-uuid"
}
```

**Respons 201**

```json
{
  "data": {
    "id": "conversation-uuid",
    "kind": "direct",
    "participants": [
      {
        "profile": {
          "id": "profile-uuid",
          "name": "Deg",
          "mode": "private"
        },
        "role": "owner"
      }
    ]
  }
}
```

### Hente meldinger

`GET /api/conversations/{conversation_id}/messages?limit=50`

**Respons 200**

```json
{
  "data": [
    {
      "id": "message-uuid",
      "body": "Hei",
      "status": "sent",
      "sent_at": "2024-10-04T12:00:00Z",
      "inserted_at": "2024-10-04T12:00:00Z",
      "profile": {
        "id": "profile-uuid",
        "name": "Deg",
        "mode": "private"
      }
    }
  ]
}
```

### Sende melding

`POST /api/conversations/{conversation_id}/messages`

```json
{
  "message": {
    "body": "Hei på deg"
  }
}
```

**Respons 201**

```json
{
  "data": {
    "id": "message-uuid",
    "body": "Hei på deg",
    "status": "sent",
    "sent_at": "2024-10-04T12:00:00Z",
    "inserted_at": "2024-10-04T12:00:00Z",
    "profile": {
      "id": "profile-uuid",
      "name": "Deg",
      "mode": "private"
    }
  }
}
```

Ved valideringsfeil returneres `422` med `{"errors": {"field": ["message"]}}`.

## WebSocket / WSS

Sanntid skjer via Phoenix Channels. Klienter skal koble til `ws://` eller `wss://` basert på API-basens skjema.

### Handshake

- URL: `wss://{vert}/socket/websocket?vsn=2.0.0`
- Protokoll: Phoenix Channel
- Etter tilkobling må klienten joine `conversation:{conversation_id}` med payload:

```json
{
  "account_id": "acct-uuid",
  "profile_id": "profile-uuid"
}
```

Manglende eller ugyldige verdier gir `{ "reason": "unauthorized" }` eller `{ "reason": "forbidden" }` som join-feil.

### Hendelser

| Retning | Event | Payload | Beskrivelse |
|---------|-------|---------|-------------|
| Klient → Server | `message:create` | `{ "body": "tekst" }` | Sender en ny melding i samtalen. Tomme strenger avvises. |
| Server → Klient | `message_created` | `{ "data": { ... } }` | Sendes til alle deltakere når en melding lagres. Strukturen matcher REST-responsen for melding. |
| Server → Klient (reply) | `{:ok, {"data": { ... }}}` | Returneres som svar på `message:create` ved suksess. Feil gir `{ "errors": ... }`. |

Klienten bør lytte på `message_created` og merge meldinger basert på `id` for å unngå duplikater.

### Feilhåndtering

- Join uten gyldig medlemskap gir `{ "reason": "forbidden" }`.
- `message:create` kan svare med `{ "errors": {"body": ["can't be blank"]} }` for valideringsfeil.
- Timeout på push håndteres som transportfeil; klient bør prøve HTTP som fallback.

## Statuskoder og feilformat

- `401 Unauthorized`: Manglende eller ugyldige identitetsheadere.
- `403 Forbidden`: Profil er ikke deltaker i samtalen.
- `404 Not Found`: Samtale eller ressurs finnes ikke.
- `422 Unprocessable Entity`: Valideringsfeil. Body: `{ "errors": {"felt": ["beskjed"]} }`.
- `500 Internal Server Error`: Uventet feil. Body: `{ "errors": ["internal_error"] }`.

## Versjonering

Kontrakten er per oktober 2024 rettet inn mot en chat-MVP. Endringer som bryter kontrakten skal dokumenteres her og i `CHANGELOG.md`.
