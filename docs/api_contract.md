# API-kontrakt for msgr

Denne siden dokumenterer forventet kontrakt mellom msgr-backend og Flutter-klienten. Alle responser er JSON-kodet og bruker snake_case i feltnavn med mindre annet er spesifisert.

## Autentisering og identitet

- Beskyttede HTTP-kall under `/api` (pipeline `:actor`) krever
  `Authorization: Bearer <access JWT>` (`MessngrWeb.Plugs.SessionContext`).
- Konto (`sub`) og profil (`pid`) tas **kun** fra verifiserte JWT-claims.
  Legacy-headere `X-Account-Id` / `X-Profile-Id` er **ikke** tillitvekkende
  og erstatter ikke Bearer-token.
- Ugyldig/manglende token → `401 Unauthorized`.
- WebSocket: foretrekk connect-param `token` (samme access JWT). Gateway kan
  fortsatt sende `account_id` / `profile_id` etter egen validering (se under).

## Noise-håndtrykk og nøkkelhåndtering

- Klienten fungerer alltid som **initiator**, serveren som **responder** i `Noise_NX_25519_ChaChaPoly_Blake2b`-handtrykket. Transporten er feature-togglet i backend via `NOISE_TRANSPORT_ENABLED` og lytter på en dedikert TCP-port (default `5443`).
- Handshake-prologen er strengen `"msgr-noise/v1"` (UTF-8) og må inkluderes i begge ender for å binde protokollversjon til nøkkelen.
- Klienten forventer at serveren presenterer en statisk Curve25519-nøkkel. Fingerprint (BLAKE2b-256 i hex) brukes til å validere nøkkelen.
- Dersom fingerprint ikke er kjent lokalt forsøker klienten først å hente siste nøkkelmateriale fra `GET /api/noise/server-key` (beskrevet under) før den gjør et nytt handshake.
- Hvis Noise `NX`-handshake feiler på grunn av nettverk eller tidsavvik, skal klienten falle tilbake til et `Noise_XX_25519_ChaChaPoly_Blake2b`-handtrykk. Dette gir gjensidig autentisering via ephemeral-nøkler, men klienten må da etablere ny sesjonsnøkkel og be backend om et nytt autorisasjonstoken.

### Hente serverens statiske nøkkel

`GET /api/noise/server-key`

Tilgjengelig når Noise-transporten er aktivert.

Valgfrie query-parametre:

| Parameter | Beskrivelse |
| --- | --- |
| `fingerprint_only` | Hvis `true`, returneres kun fingerprint (nyttig for rask validering). |

**Respons 200**

```json
{
  "data": {
    "protocol": "Noise_NX_25519_ChaChaPoly_Blake2b",
    "prologue": "msgr-noise/v1",
    "static_public_key": "BASE64_CURVE25519_PUB",
    "fingerprint": "0a4f7e...",
    "rotated_at": "2024-10-08T13:37:00Z",
    "expires_at": null
  }
}
```

Når `fingerprint_only=true` blir `data` redusert til `{ "fingerprint": "..." }`.

Feil:

- `404 Not Found` hvis nøkkel ikke er initialisert i backend.
- `503 Service Unavailable` hvis backend ikke kan nå Secrets Manager for å hente nøkkel.

### OTP-innlogging (e-post og mobil)

Ruter (verifisert i `MessngrWeb.Router`): `POST /api/v1/auth/challenge`,
`/verify`, `/oidc`, `/refresh`, `/bot-token`.

1. **Start utfordring**

   `POST /api/v1/auth/challenge`

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
   Challenge-TTL er **10 minutter**. Koden lagres som HMAC (`OTP_HMAC_SECRET`,
   fallback `SECRET_KEY_BASE`) — se `docs/SECRET_MANAGEMENT.md`.

2. **Verifiser engangskode**

   `POST /api/v1/auth/verify`

   ```json
   {
     "challenge_id": "challenge-uuid",
     "code": "123456",
     "display_name": "Kari Nordmann",
     "noise_session_id": "session-uuid",
     "noise_signature": "base64url-hmac",
     "last_handshake_at": "2024-10-05T08:45:32Z"
   }
   ```

   Se også `docs/noise_handshake_rollout.md` for handshake-detaljer og hvordan
   signaturen genereres.

   **Feil / lockout (SEC-4):** Maks **5** mislykkede verifiseringsforsøk per
   challenge (`Messngr.Auth` `@max_verify_attempts`). Tellere økes atomisk.
   Når grensen er nådd: **429** med `{"error":"too_many_attempts"}` — start en
   ny challenge. Feil kode før lockout: typisk **400**. Utløpt/konsumert
   challenge: **400** med tilhørende feilkode.

   **Respons 200**

   ```json
   {
     "account": {
       "id": "acct-uuid",
       "display_name": "Kari Nordmann",
       "email": "kari@example.com",
       "phone_number": null,
       "profiles": [
         {
           "id": "profile-uuid",
           "name": "Kari",
           "slug": "kari",
           "mode": "personal",
           "avatar_url": null
         }
       ]
     },
     "profile_id": "profile-uuid",
     "profile": {
       "id": "profile-uuid",
       "name": "Kari",
       "slug": "kari",
       "mode": "personal",
       "avatar_url": null
     },
     "identity": {
       "id": "identity-uuid",
       "kind": "email",
       "verified_at": "2024-10-04T12:01:00Z"
     },
     "access_token": "GuardianAccessJWT",
     "refresh_token": "GuardianRefreshJWT"
   }
   ```

   Bruk `access_token` som `Authorization: Bearer …` på videre REST/WS-kall.
   Forny med `POST /api/v1/auth/refresh` `{ "refresh_token": "…" }` →
   `{ "access_token": "…" }`.

   Når Noise-handshake er bundet inn (valgfritt / feature-flag), kan responsen
   også inneholde `noise_session: { "id", "token" }`. Det erstatter **ikke**
   JWT for `:actor`-ruter i dagens `SessionContext`.

   Samme flyt gjelder for `channel: "phone"` hvor `identifier` er et E.164-nummer.

### Federert pålogging (OIDC)

`POST /api/v1/auth/oidc`

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

### Importere kontakter

`POST /api/contacts/import`

Klienten sender inn en batch med kontakter som skal knyttes til den aktive
kontoen. Backend lagrer (eller oppdaterer) kontakter per konto/profil og
returnerer de normaliserte radene. Requesten må autentiseres med
`Authorization: Bearer <access JWT>` (profil fra JWT `pid`).

**Request**

```json
{
  "contacts": [
    {
      "name": "Eva Nordmann",
      "email": "eva@example.com",
      "phone_number": "+47 900 00 000",
      "labels": ["venn", "jobb"],
      "metadata": {"source": "device"}
    }
  ]
}
```

**Respons 200**

```json
{
  "data": [
    {
      "id": "contact-uuid",
      "name": "Eva Nordmann",
      "email": "eva@example.com",
      "phone_number": "4790000000",
      "labels": ["venn", "jobb"],
      "metadata": {"source": "device"},
      "account_id": "acct-uuid",
      "profile_id": "profile-uuid"
    }
  ]
}
```

Valideringsfeil gir `400 Bad Request`. Ugyldige kontakter ruller hele batchen
tilbake og svarer med `422 Unprocessable Entity`.

### Matche kjente kontakter

`POST /api/contacts/lookup`

Tar inn en liste med e-poster eller telefonnumre og returnerer hvilke av dem som
matcher eksisterende msgr-identiteter. Responsen inkluderer hvilken konto som
ble funnet, hvilken identitet som traff, og et profil-sammendrag når vi kjenner
minst én profil.

**Request**

```json
{
  "targets": [
    {"email": "eva@example.com"},
    {"phone_number": "+47 900 00 000"}
  ]
}
```

**Respons 200**

```json
{
  "data": [
    {
      "query": {
        "email": "eva@example.com",
        "phone_number": null
      },
      "match": {
        "account_id": "acct-uuid",
        "account_name": "Eva Nordmann",
        "identity_kind": "email",
        "identity_value": "eva@example.com",
        "profile": {
          "id": "profile-uuid",
          "name": "Privat",
          "mode": "personal"
        }
      }
    },
    {
      "query": {
        "email": null,
        "phone_number": "4790000000"
      },
      "match": null
    }
  ]
}
```

Når ingen treff finnes returneres `match: null` for den aktuelle oppføringen.

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
        "name": "Kari",
        "mode": "personal"
      }
    ]
  }
}
```

### Hente min konto

`GET /api/account/me`

Returnerer kontoen/profilene som er knyttet til gjeldende Noise-sesjon.

**Respons 200**

```json
{
  "data": {
    "id": "acct-uuid",
    "display_name": "Kari Nordmann",
    "profiles": [
      {
        "id": "profile-uuid",
        "name": "Kari",
        "slug": "kari",
        "mode": "personal"
      }
    ]
  }
}
```

### Opprette eller hente direktemelding

`POST /api/conversations`

Krever autentisert actor-pipeline (`CurrentActor`). Idempotent 1:1 via
`Messngr.ensure_direct_conversation/2`.

```json
{
  "target_profile_id": "peer-profile-uuid"
}
```

**Respons 200** (render `:show`)

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

### Opprette gruppe- eller kanal-samtale

Samme endepunkt, med `kind` i stedet for `target_profile_id`
(`MessngrWeb.ConversationController` → `create_group_conversation` /
`create_channel_conversation`).

**Gruppe (privat group DM / gruppechat)**

```json
{
  "kind": "group",
  "participant_ids": ["profile-uuid-a", "profile-uuid-b"],
  "topic": "Helgetur",
  "structure_type": "optional-string",
  "read_receipts_enabled": true
}
```

- `participant_ids` (eller `participantIds`) er påkrevd listen utover eier;
  innlogget profil blir eier.
- Backend setter alltid `visibility: :private` for `kind: "group"`.

**Kanal**

```json
{
  "kind": "channel",
  "participant_ids": ["profile-uuid-a"],
  "topic": "general",
  "visibility": "public",
  "read_receipts_enabled": false
}
```

`visibility` kan også komme fra `access`, eller `hidden: true` → `"private"`.
Ukjent `kind` eller manglende felter → **400** `bad_request`.

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
### Forberede mediaopplasting

`POST /api/conversations/{conversation_id}/uploads`

```json
{
  "upload": {
    "kind": "image",
    "content_type": "image/png",
    "byte_size": 48123,
    "filename": "ferie.png"
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
    "object_key": "conversations/123/image/upload-uuid.png",
    "content_type": "image/png",
    "byte_size": 48123,
    "expires_at": "2024-10-04T12:15:00Z",
    "public_url": "https://cdn.example.com/msgr-media/conversations/123/image/upload-uuid.png",
    "retention_until": "2024-10-11T12:15:00Z",
    "upload": {
      "method": "PUT",
      "url": "https://storage.example.com/msgr-media/conversations/123/image/upload-uuid.png?signature=...",
      "headers": {
        "content-type": "image/png",
        "x-amz-server-side-encryption": "AES256"
      },
      "expires_at": "2024-10-04T12:05:00Z"
    },
    "download": {
      "method": "GET",
      "url": "https://cdn.example.com/msgr-media/conversations/123/image/upload-uuid.png?signature=...",
      "expires_at": "2024-10-04T12:25:00Z"
    }
  }
}
```

Klienten laster opp binæren direkte til `upload.url` før `expires_at` og sender deretter en melding med `media.upload_id` og valgfri metadata (caption, waveform, dimensjoner, checksum). Alle opplastinger må inkludere de signerede headerne – `content-type` og eventuelle `x-amz-server-side-encryption*`-felt – slik at objekter lagres kryptert i S3-kompatibel lagring.

Backend-konfigurasjonen støtter både standard SSE-S3 (`MEDIA_SSE_ALGORITHM`, default `AES256`) og KMS-nøkler (`MEDIA_SSE_KMS_KEY_ID`). Når en KMS-nøkkel er konfigurert returneres både algoritme- og nøkkel-ID-headere i opplastingsinstruksjonene.

**Team-media (annen pipeline):** Presign / complete / download under
`/api/teams/:slug/media…` går via ClamAV-skanning og er **ikke** det samme som
personlige conversation-uploads over. Se `docs/media_virus_scan.md` for statuskoder,
quarantine og miljøvariabler. Personlig media har fortsatt ikke virus-scan.

### Eksempel på mediamelding

```json
{
  "message": {
    "kind": "image",
    "media": {
      "upload_id": "upload-uuid",
      "caption": "Ferie!",
      "width": 1280,
      "height": 720,
      "checksum": "d41d8cd98f00b204e9800998ecf8427e"
    }
  }
}
```

**Respons 201**

```json
{
  "data": {
    "id": "message-uuid",
    "type": "image",
    "status": "sent",
    "sent_at": "2024-10-04T12:16:00Z",
    "inserted_at": "2024-10-04T12:16:00Z",
    "profile": {
      "id": "profile-uuid",
      "name": "Deg",
      "mode": "private"
    },
    "payload": {
      "media": {
        "url": "https://cdn.example.com/msgr-media/conversations/123/image/upload-uuid.png?signature=...",
        "contentType": "image/png",
        "byteSize": 48123,
        "checksum": "d41d8cd98f00b204e9800998ecf8427e",
        "width": 1280,
        "height": 720,
        "caption": "Ferie!",
        "retention": {
          "expiresAt": "2024-10-11T12:15:00Z"
        },
        "thumbnail": {
          "url": "https://cdn.example.com/msgr-media/conversations/123/image/upload-uuid.png?thumb=1",
          "width": 320,
          "height": 180
        }
      }
    }
  }
}
```

Backenden normaliserer også lydmeldinger (`type: "audio"` eller `"voice"`) med `waveform` og `duration`, samt generiske filer (`type: "file"`) som eksponerer `fileName`, `byteSize`, `checksum` og valgfritt `thumbnail`.
### Realtime ConversationChannel

- **Join**: `conversation:{conversation_id}`
  - Params: `{ "account_id": "...", "profile_id": "..." }`
- **Events**:
  - `message_created` / `message_updated`: `{ "data": { ...message payload med metadata, edited_at, deleted_at, thread_id } }`
  - `message_deleted`: `{ "message_id": "uuid", "deleted_at": "2024-10-04T12:10:00Z" }`
  - `reaction_added` / `reaction_removed`:

    ```json
    {
      "id": "reaction-uuid",
      "message_id": "message-uuid",
      "profile_id": "profile-uuid",
      "emoji": "👍",
      "metadata": {},
      "aggregates": [
        { "emoji": "👍", "count": 2, "profile_ids": ["profile-uuid", "peer-uuid"] }
      ]
    }
    ```

  - `message_pinned` / `message_unpinned`: `{ "message_id": "uuid", "pinned_by_id": "profile", "pinned_at": "2024-10-04T12:15:00Z", "metadata": {} }`
  - `message_read`: `{ "profile_id": "profile-uuid", "message_id": "message-uuid", "read_at": "2024-10-04T12:12:00Z" }`
  - `typing_started` / `typing_stopped`: `{ "profile_id": "profile-uuid", "profile_name": "Kari", "thread_id": null, "expires_at": "2024-10-04T12:05:05Z" }`
  - `conversation_watchers`: `{ "count": 2, "watchers": [{ "id": "profile-uuid", "name": "Kari", "mode": "private" }] }`
  - Presence diff/stat er levert via Phoenix `presence_state` og `presence_diff` events.

- **Client events**:
  - `typing:start` / `typing:stop` (payload `{ "thread_id": "optional-thread" }`)
  - `message:read`, `reaction:add`, `reaction:remove`, `message:update`, `message:delete`
  - `message:pin`, `message:unpin`
  - `conversation:watch`, `conversation:unwatch`

`conversation:watch` holder en profiler-liste aktiv i maks 30 sekunder per invitasjon
(`conversation_watcher_ttl_ms` kan overstyres i konfig). Når tiden utløper vil
backenden automatisk droppe profilen fra `conversation_watchers`-strømmen og
returnere en tom liste ved neste `list_watchers`-kall.

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

## E2EE (personlig 1:1 tekst)

Normativt: [e2ee_spec.md](e2ee_spec.md). Utvikler-runbook: [e2ee_developer.md](e2ee_developer.md).

Valgfri nøkkelkatalog (tom liste er OK — aldri send-blokkering):

### Last opp enhetsnøkler

`PUT /api/v1/e2ee/keys`

```json
{
  "device_id": "dev-1",
  "identity_key": "BASE64_32B",
  "signed_prekey": "BASE64_32B",
  "spk_id": 1,
  "spk_signature": "BASE64_64B",
  "one_time_prekeys": [
    { "opk_id": 10, "public_key": "BASE64_32B" }
  ]
}
```

**Respons 200:** `{ "data": { "device_id", "spk_id", "one_time_prekey_count" } }`.
Ubrukte OPK-er for enheten erstattes av batchen.

### Hent bundles

`GET /api/v1/e2ee/bundles/:profile_id` → `{ "data": [ … ] }` (kan være `[]`).
Hvert kall **konsumerer** én ubrukt OPK per enhet når den finnes.

### Tell gjenværende OPK-er

`GET /api/v1/e2ee/keys/count?device_id=dev-1` →
`{ "data": { "device_id", "one_time_prekey_count" } }`.
Uten `device_id`: `400`.

### Kryptert melding (opaque relay)

`POST /api/conversations/{conversation_id}/messages`

```json
{
  "message": {
    "kind": "encrypted",
    "body": "",
    "payload": {
      "v": 1,
      "e2ee": {
        "sid": "dev-1",
        "iv_ct": null,
        "keys": [
          {
            "rid": "*",
            "type": "init",
            "ik": "BASE64",
            "ek": "BASE64",
            "header": { "dh": "BASE64", "pn": 0, "n": 0 },
            "ct": null
          }
        ]
      }
    }
  }
}
```

**Respons 201:** `type` er `"encrypted"`, `body` er tom (server tvinger `""`),
`payload.e2ee` returneres uendret. Mangler `payload.e2ee` → valideringsfeil.
Ved `rid: "*"` kan `metadata.e2ee_fanout_device_ids` fylles med enhets-IDer
fra nøkkelkatalogen (hint til klienter; midlertidig til #235).

## WebSocket / WSS

Sanntid skjer via Phoenix Channels. Klienter skal koble til `ws://` eller `wss://` basert på API-basens skjema.

### Handshake

- URL: `wss://{vert}/socket/websocket?vsn=2.0.0`
- Protokoll: Phoenix Channel
- **Anbefalt:** connect med `{ "token": "<access JWT>" }` (`UserSocket` JWT-gren).
- Alternativ (f.eks. Rust gateway): `account_id` / `profile_id` (og valgfritt
  `device_id` / `session_id`) etter gateway-validering.
- Team/kanal-topics: `channel:*`, `team:*`, `presence:*`, `rtc:*` (se
  `MessngrWeb.UserSocket`). Join-autorisasjon bruker socket-assigns, ikke
  trustede klient-headere alene.

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

- `401 Unauthorized`: Manglende eller ugyldig `Authorization: Bearer` JWT.
- `403 Forbidden`: Profil er ikke deltaker i samtalen.
- `404 Not Found`: Samtale eller ressurs finnes ikke.
- `422 Unprocessable Entity`: Valideringsfeil. Body: `{ "errors": {"felt": ["beskjed"]} }`.
- `429 Too Many Requests`: OTP lockout (`too_many_attempts`) eller rate limits.
- `500 Internal Server Error`: Uventet feil. Body: `{ "errors": ["internal_error"] }`.

## Versjonering

Kontrakten er per oktober 2024 rettet inn mot en chat-MVP. Endringer som bryter kontrakten skal dokumenteres her og i `CHANGELOG.md`.
