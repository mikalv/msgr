# API-kontrakt for msgr

Denne siden dokumenterer forventet kontrakt mellom msgr-backend og Flutter-klienten. Alle responser er JSON-kodet og bruker snake_case i feltnavn med mindre annet er spesifisert.

## Autentisering og identitet

- HTTP-klienten identifiserer seg med to obligatoriske headere på alle samtalerelaterte kall:
  - `x-account-id`: UUID for kontoen som er aktiv i klienten.
  - `x-profile-id`: UUID for profilen som sender/leser meldinger.
- Backend verifiserer at profilen tilhører kontoen. Mismatch gir `401 Unauthorized`.
- WebSocket-tilkoblingen bruker de samme verdiene som join-parametre (se under).

### OTP-innlogging (e-post og mobil)

1. **Start utfordring**

   `POST /api/auth/challenge`

   ```json
   {
     "channel": "email",
     "identifier": "kari@example.com",
     "device_id": "optional-device-uuid"
   }
   ```

   **Respons 201**

   ```json
   {
     "id": "challenge-uuid",
     "channel": "email",
     "expires_at": "2024-10-04T12:00:00Z",
     "target_hint": "ka***@example.com",
     "debug_code": "123456"
   }
   ```

   `debug_code` returneres kun i dev/test og skal aldri vises i produksjon.

2. **Verifiser engangskode**

   `POST /api/auth/verify`

   ```json
   {
     "challenge_id": "challenge-uuid",
     "code": "123456",
     "display_name": "Kari Nordmann"
   }
   ```

   **Respons 200**

   ```json
   {
     "account": {
       "id": "acct-uuid",
       "display_name": "Kari Nordmann",
       "email": "kari@example.com",
       "phone_number": null
     },
     "identity": {
       "id": "identity-uuid",
       "kind": "email",
       "verified_at": "2024-10-04T12:01:00Z"
     }
   }
   ```

   Samme flyt gjelder for `channel: "phone"` hvor `identifier` er et E.164-nummer.

### Federert pålogging (OIDC)

`POST /api/auth/oidc`

```json
{
  "provider": "azuread",
  "subject": "OIDC-subject",
  "email": "kari@example.com",
  "name": "Kari Nordmann"
}
```

**Respons 200** matcher `verify`-kallet.

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
      "type": "image",
      "body": "Skisse",
      "status": "sent",
      "sent_at": "2024-10-04T12:00:00Z",
      "inserted_at": "2024-10-04T12:00:00Z",
      "payload": {
        "media": {
          "bucket": "msgr-media",
          "objectKey": "conversations/<id>/image/<uuid>.png",
          "url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>.png",
          "contentType": "image/png",
          "byteSize": 102400,
          "width": 1920,
          "height": 1080,
          "caption": "Skisse",
          "thumbnail": {
            "url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>-thumbnail.png",
            "width": 320,
            "height": 180
          },
          "retentionExpiresAt": "2024-11-04T12:00:00Z"
        }
      },
      "media": {
        "bucket": "msgr-media",
        "objectKey": "conversations/<id>/image/<uuid>.png",
        "url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>.png",
        "contentType": "image/png",
        "byteSize": 102400,
        "width": 1920,
        "height": 1080,
        "caption": "Skisse",
        "thumbnail": {
          "url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>-thumbnail.png",
          "width": 320,
          "height": 180
        },
        "retentionExpiresAt": "2024-11-04T12:00:00Z"
      },
      "profile": {
        "id": "profile-uuid",
        "name": "Deg",
        "mode": "private"
      }
    }
  ],
  "meta": {
    "start_cursor": "message-uuid",
    "end_cursor": "message-uuid",
    "has_more": {"before": false, "after": false}
  }
}
```

`media`-feltet er en forhåndsnormalisert representasjon av `payload.media`. Den
kan brukes direkte av klienter til å gjengi vedlegg uten å måtte vite alt om
intern lagringsstruktur.

### Familie-spaces med kalender, handleliste og todo

`GET /api/families`

Returnerer alle familier den aktive profilen er medlem av.

```json
{
  "data": [
    {
      "id": "family-uuid",
      "name": "Team Berg",
      "slug": "team-berg",
      "kind": "family",
      "time_zone": "Europe/Oslo",
      "memberships": [
        {
          "id": "membership-uuid",
          "role": "owner",
          "profile": {
            "id": "profile-uuid",
            "name": "Kari",
            "slug": "kari"
          }
        }
      ]
    }
  ]
}
```

`POST /api/families`

```json
{
  "family": {
    "name": "Familien Hansen",
    "time_zone": "Europe/Oslo"
  }
}
```

**Respons 201** gir samme struktur som `GET /api/families/{id}`.

`GET /api/families/{family_id}` krever at profilen er medlem og returnerer familieobjektet med alle medlemmer.

`GET /api/families/{family_id}/events?from=2024-10-04T00:00:00Z&to=2024-10-10T23:59:59Z`

Filtrerer kalenderhendelser innenfor tidsintervallet. `from` og `to` er valgfrie og bruker ISO8601 med tidssone.

```json
{
  "data": [
    {
      "id": "event-uuid",
      "space_id": "family-uuid",
      "family_id": "family-uuid",
      "title": "Foreldremøte",
      "description": null,
      "location": "Teams",
      "starts_at": "2024-10-05T18:00:00Z",
      "ends_at": "2024-10-05T19:00:00Z",
      "all_day": false,
      "color": "#ff8800",
      "created_by_profile_id": "profile-uuid",
      "updated_by_profile_id": "profile-uuid",
      "creator": {
        "id": "profile-uuid",
        "name": "Kari",
        "slug": "kari"
      },
      "updated_by": {
        "id": "profile-uuid",
        "name": "Kari",
        "slug": "kari"
      },
      "inserted_at": "2024-10-04T12:00:00Z",
      "updated_at": "2024-10-04T12:00:00Z"
    }
  ]
}
```

`POST /api/families/{family_id}/events`

```json
{
  "event": {
    "title": "Felles middag",
    "starts_at": "2024-10-06T16:00:00Z",
    "ends_at": "2024-10-06T17:30:00Z",
    "color": "#00c896"
  }
}
```

`PATCH /api/families/{family_id}/events/{event_id}` og `DELETE /api/families/{family_id}/events/{event_id}` krever medlemskap og oppdaterer eller fjerner hendelsen. `starts_at` og `ends_at` må være ISO8601.

#### Handlelister

`GET /api/families/{family_id}/shopping_lists`

Returnerer aktive handlelister. Bruk query-parameteren `include_archived=true` for å inkludere arkiverte lister.

```json
{
  "data": [
    {
      "id": "list-uuid",
      "space_id": "family-uuid",
      "name": "Helg",
      "status": "active",
      "items": [
        {
          "id": "item-uuid",
          "name": "Melk",
          "quantity": "2",
          "checked": false
        }
      ]
    }
  ]
}
```

`POST /api/families/{family_id}/shopping_lists`

```json
{
  "list": {
    "name": "Hverdager"
  }
}
```

`POST /api/families/{family_id}/shopping_lists/{list_id}/items`

```json
{
  "item": {
    "name": "Egg",
    "quantity": "12",
    "checked": false
  }
}
```

Elementer kan oppdateres med `PUT /api/families/{family_id}/shopping_lists/{list_id}/items/{item_id}` (f.eks. `{"item": {"checked": true}}`) og slettes med `DELETE` på samme sti.

#### Generelle todo-lister

`GET /api/families/{family_id}/todo_lists`

Returnerer alle todolister og deres oppgaver. Listen kan arkiveres ved å sette `status` til `archived` via `PUT`.

```json
{
  "data": [
    {
      "id": "todo-list-uuid",
      "space_id": "family-uuid",
      "name": "Oppgaver",
      "status": "active",
      "items": [
        {
          "id": "todo-item-uuid",
          "content": "Støvsug stua",
          "status": "pending",
          "assignee_profile_id": "profile-uuid"
        }
      ]
    }
  ]
}
```

`POST /api/families/{family_id}/todo_lists`

```json
{
  "list": {
    "name": "Ukeplan"
  }
}
```

`POST /api/families/{family_id}/todo_lists/{list_id}/items`

```json
{
  "item": {
    "content": "Bestille mat",
    "assignee_profile_id": "profile-uuid",
    "due_at": "2024-10-07T10:00:00Z"
  }
}
```

Oppdater status med `PUT /api/families/{family_id}/todo_lists/{list_id}/items/{item_id}` (`{"item": {"status": "done"}}`). Når `status` settes til `done` registreres automatisk hvem som fullførte oppgaven.

`GET /api/families/{family_id}/notes`

```json
{
  "data": [
    {
      "id": "note-uuid",
      "title": "Ukemeny",
      "body": "Mandag: Suppe",
      "color": "sunshine",
      "pinned": true,
      "created_by_profile_id": "profile-uuid",
      "updated_by_profile_id": "profile-uuid",
      "inserted_at": "2024-10-07T10:00:00Z",
      "updated_at": "2024-10-07T10:15:00Z"
    }
  ]
}
```

Legg til `?pinned_only=true` i query-string for å kun hente notater som er markert som festet.

`POST /api/families/{family_id}/notes`

```json
{
  "note": {
    "title": "Pakkeliste høstferien",
    "body": "Ski, votter, ullsokker",
    "pinned": false
  }
}
```

`PUT /api/families/{family_id}/notes/{note_id}`

```json
{
  "note": {
    "title": "Oppdatert pakkeliste",
    "pinned": true
  }
}
```

Slett notater med `DELETE /api/families/{family_id}/notes/{note_id}`. Feltet `pinned` aksepterer både booleans og tekstverdier (`"true"`, `"false"`).

### Sende melding

### Opprette mediaopplasting

`POST /api/conversations/{conversation_id}/uploads`

```json
{
  "upload": {
    "kind": "image",
    "content_type": "image/png",
    "byte_size": 102400,
    "filename": "skisse.png"
  }
}
```

**Respons 201**

```json
{
  "data": {
    "id": "upload-uuid",
    "kind": "image",
    "status": "pending",
    "bucket": "msgr-media",
    "object_key": "conversations/<id>/image/<uuid>.png",
    "content_type": "image/png",
    "byte_size": 102400,
    "expires_at": "2024-10-04T12:15:00Z",
    "upload": {
      "method": "PUT",
      "url": "https://storage.local/msgr-media/conversations/<id>/image/<uuid>.png?...",
      "headers": {
        "content-type": "image/png"
      },
      "bucket": "msgr-media",
      "object_key": "conversations/<id>/image/<uuid>.png",
      "public_url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>.png",
      "expires_at": "2024-10-04T12:15:00Z",
      "retention_expires_at": "2024-11-04T12:00:00Z",
      "thumbnail_upload": {
        "method": "PUT",
        "url": "https://storage.local/msgr-media/conversations/<id>/image/<uuid>-thumbnail.png?...",
        "headers": {
          "content-type": "image/jpeg"
        },
        "bucket": "msgr-media",
        "object_key": "conversations/<id>/image/<uuid>-thumbnail.png",
        "public_url": "https://cdn.msgr.no/msgr-media/conversations/<id>/image/<uuid>-thumbnail.png",
        "expires_at": "2024-10-04T12:15:00Z"
      }
    }
  }
}
```

Klienten laster opp originalfilen (og eventuell thumbnail) direkte til URL-ene
før den sender meldingen med `upload_id`.

`POST /api/conversations/{conversation_id}/messages`

```json
{
  "message": {
    "kind": "voice",
    "body": "Hør på dette",
    "media": {
      "upload_id": "upload-uuid",
      "durationMs": 2400,
      "caption": "Hør på dette",
      "waveform": [0, 10, 20]
    }
  }
}
```

**Respons 201**

```json
{
  "data": {
    "id": "message-uuid",
    "type": "voice",
    "body": "Hør på dette",
    "status": "sent",
    "sent_at": "2024-10-04T12:00:00Z",
    "inserted_at": "2024-10-04T12:00:00Z",
    "media": {
      "url": "https://cdn.msgr.no/msgr-media/conversations/<id>/voice/<uuid>.ogg",
      "contentType": "audio/ogg",
      "durationMs": 2400,
      "waveform": [0, 10, 20]
    },
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
