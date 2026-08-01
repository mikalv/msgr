# Sikkerhetsgjennomgang: msgr

**Dato:** 2026-08-01  
**Utført av:** Fable (manuell kodegjennomgang)  
**Omfang:** Backend auth-flyt, session-håndtering, multi-tenant tilgangskontroll, webhooks, media, Noise/Rust-gateway

> Merk: Dette er en manuell kildekode-gjennomgang, ikke en erstatning for en uavhengig sikkerhetsrevisjon (se [#196](https://github.com/mikalv/msgr/issues/196)). Ingen dynamisk testing/pentest er utført (Elixir-toolchain ikke tilgjengelig i miljøet).

---

## Alvorlighetsoversikt

| ID | Alvorlighet | Funn |
|----|-------------|------|
| SEC-1 | 🔴 Kritisk | OTP-koder genereres med ikke-kryptografisk PRNG (`:rand.uniform`) |
| SEC-2 | 🔴 Kritisk | Brutt tilgangskontroll i team-API — flere endepunkter mangler medlemskapssjekk (cross-tenant IDOR) |
| SEC-3 | 🔴 Kritisk | Media-nedlasting aksepterer vilkårlig `object_key` (cross-tenant fil-tilgang) |
| SEC-4 | 🟠 Høy | OTP-koder lagres som usaltet SHA-256 av 6-sifret rom (trivielt å brute-force ved DB-lekkasje) |
| SEC-5 | 🟠 Høy | Ingen kanal-nivå autorisasjon — team-medlem kan lese/skrive i private kanaler de ikke er med i |
| SEC-6 | 🟡 Medium | Bot-secret sammenlignes ikke i konstant tid (timing-angrep) |
| SEC-7 | 🟡 Medium | Hardkodede secrets i `docker-compose.yml` (dekket av [#193](https://github.com/mikalv/msgr/issues/193)) |
| SEC-8 | 🟢 Lav | Misvisende `authorization_schemes: [:noise]`-opsjon som er en no-op |

---

## SEC-1 🔴 OTP-koder med usikker tilfeldighet

**Fil:** `backend/apps/msgr/lib/msgr/auth.ex:469-471`

```elixir
defp generate_code do
  :rand.uniform(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")
end
```

`:rand.uniform/1` bruker Erlangs standard PRNG (`exsss`), som **ikke er kryptografisk sikker**. Tilstanden er per-prosess og seedes deterministisk. En angriper som kan observere noen OTP-koder (f.eks. via egne innlogginger) kan potensielt rekonstruere PRNG-tilstanden og forutsi andre brukeres koder. Dette er en autentiseringskode — den må være uforutsigbar.

**Anbefaling:**

```elixir
defp generate_code do
  :crypto.strong_rand_bytes(4)
  |> :binary.decode_unsigned()
  |> rem(1_000_000)
  |> Integer.to_string()
  |> String.pad_leading(6, "0")
end
```

Vurder også å øke kodelengden til 8 sifre og begrense antall verifiseringsforsøk per challenge (i dag kan `verify` kalles gjentatte ganger så lenge challenge ikke er konsumert/utløpt — kombinert med kort kode gir dette brute-force-rom innen 10-minutters TTL).

---

## SEC-2 🔴 Brutt tilgangskontroll i team-API (cross-tenant IDOR)

**Filer:**
- `backend/apps/msgr_web/lib/msgr_web/plugs/tenant_from_slug.ex`
- `backend/apps/msgr_web/lib/msgr_web/controllers/team_channel_controller.ex`
- `backend/apps/msgr_web/lib/msgr_web/controllers/team_message_controller.ex`

`TenantFromSlug`-plugen slår kun opp teamet fra `:slug` og setter `tenant_prefix` — den **verifiserer ikke at innlogget konto er medlem av teamet**:

```elixir
# tenant_from_slug.ex
case Teams.Repo.get_by(Teams.Schemas.Team, slug: slug) do
  nil -> ... 404
  team -> assign(conn, :current_team, team) |> assign(:tenant_prefix, team.schema_name)
end
```

Medlemskap håndheves derfor kun i controllerne som eksplisitt kaller `TeamManagement.get_profile_for_account/2` og sjekker `nil`. Flere endepunkter gjør **ikke** dette:

| Endepunkt | Fil:linje | Sjekk |
|-----------|-----------|-------|
| `GET .../channels/:id/messages` | `team_message_controller.ex:11` | ❌ Ingen medlemskapssjekk |
| `POST .../channels/:id/members` | `team_channel_controller.ex:96` | ❌ Ingen sjekk |
| `DELETE .../channels/:id/members/:pid` | `team_channel_controller.ex:143` | ❌ Ingen sjekk |
| `GET .../channels/:id/members` | `team_channel_controller.ex:121` | ❌ Ingen sjekk |
| `GET/PUT .../channels/:id/apps/:app/config` | `team_channel_controller.ex:153,167` | ❌ Ingen sjekk |

**Konsekvens:** Enhver autentisert bruker (også en som ikke er medlem av teamet) som kjenner en team-`slug` og en `channel_id` kan:
- Lese alle meldinger i vilkårlig kanal i vilkårlig team
- Legge til/fjerne medlemmer i kanaler
- Lese/endre app-konfigurasjon

Dette er horisontal privilegie-eskalering på tvers av tenants — en av de mest alvorlige feilklassene for en meldingstjeneste.

**Anbefaling:** Håndhev medlemskap sentralt. Legg en `RequireTeamMembership`-plug rett etter `:tenant` i pipeline som slår opp `get_profile_for_account` og halter med 403 hvis `nil`. Assign profilen til `conn` slik at controllere gjenbruker den. For medlems-administrasjon og app-config bør det i tillegg kreves `owner`/`admin`-rolle.

---

## SEC-3 🔴 Media-nedlasting med vilkårlig object_key

**Fil:** `backend/apps/msgr_web/lib/msgr_web/controllers/team_media_controller.ex:74-98`

```elixir
def download_url(conn, %{"object_key" => object_key_encoded}) do
  ...
  profile = TeamManagement.get_profile_for_account(prefix, account.id)
  unless profile do
    {:error, :forbidden}
  else
    object_key = URI.decode(object_key_encoded)   # klientstyrt, ingen validering
    %{url: url, expires_at: expires_at} = Storage.presign_download(bucket, object_key)
    ...
  end
end
```

`object_key` kommer direkte fra URL-en og brukes usjekket til å generere en presignert nedlastings-URL. Ved opplasting settes nøkkelen til `teams/#{team.id}/...`, men ved nedlasting valideres **ikke** at `object_key` tilhører det aktuelle teamet, eller at det finnes en `MediaUpload`-rad i tenant-skjemaet.

**Konsekvens:** Et medlem av team A kan be om `object_key = "teams/<team_B_id>/.../fil.pdf"` og få en gyldig presignert URL til et annet teams filer. Cross-tenant fil-tilgang.

**Anbefaling:** Slå opp `MediaUpload` på `object_key` innenfor `prefix` og avvis hvis den ikke finnes. Verifiser i tillegg at nøkkelen har prefikset `teams/#{team.id}/`. Ikke stol på klientlevert nøkkel.

---

## SEC-4 🟠 Usaltet SHA-256 av OTP-kode

**Fil:** `backend/apps/msgr/lib/msgr/auth.ex:473`

```elixir
defp hash_code(code), do: :crypto.hash(:sha256, code) |> Base.encode64()
```

Kodene er 6 sifre (kun 1 000 000 mulige verdier) og hashes uten salt. Ved en database-lekkasje kan alle aktive `code_hash` reverseres umiddelbart med en forhåndsberegnet tabell (10⁶ SHA-256 er trivielt). Sammenligningen i `compare_code/2` bruker riktignok `Plug.Crypto.secure_compare/2` (bra), men lagringen er svak.

**Anbefaling:** Bruk en nøkkelbundet MAC (f.eks. `:crypto.mac(:hmac, :sha256, secret_key, code)`) med en server-hemmelighet, eller en langsom KDF. Kombinert med lengre koder (SEC-1) reduseres brute-force-risiko betydelig.

---

## SEC-5 🟠 Manglende kanal-nivå autorisasjon

**Fil:** `backend/apps/msgr_web/lib/msgr_web/controllers/team_message_controller.ex:24-40`

`create/2` verifiserer at avsender har en profil i teamet, men **ikke** at profilen er medlem av `channel_id`. En hvilken som helst team-medlem kan dermed poste (og lese, jf. SEC-2) i private kanaler de ikke er invitert til.

**Anbefaling:** Verifiser `ChannelMembership` for `channel_id` + `profile_id` før lesing/skriving i ikke-offentlige kanaler.

---

## SEC-6 🟡 Bot-secret uten konstant-tid-sammenligning

**Fil:** `backend/apps/msgr_web/lib/msgr_web/controllers/auth_controller.ex:41`

```elixir
secret != configured_secret ->
  conn |> put_status(:unauthorized) |> json(%{error: "invalid_secret"})
```

Vanlig `!=` på strenger er ikke konstant-tid og kan i teorien lekke informasjon om hemmeligheten via responstid. Bot-token gir full konto-tilgang uten OTP, så dette er verdt å tette.

**Anbefaling:**

```elixir
Plug.Crypto.secure_compare(secret, configured_secret)
```

---

## SEC-7 🟡 Hardkodede secrets

Dekket av eksisterende issue [#193](https://github.com/mikalv/msgr/issues/193). `SECRET_KEY_BASE` og Rust `SERVER_STATIC_KEY` ligger i klartekst i `docker-compose.yml`. `SECRET_KEY_BASE` brukes til å signere Guardian-JWT-er — lekkasje muliggjør forfalskning av gyldige access tokens for vilkårlig konto.

---

## SEC-8 🟢 Misvisende autorisasjonsopsjon

**Fil:** `router.ex:9`

```elixir
plug MessngrWeb.Plugs.CurrentActor, authorization_schemes: [:noise]
```

`CurrentActor`/`SessionContext` ignorerer opsjonen fullstendig og gjør kun JWT-validering. Opsjonen er en no-op og kan villede fremtidige lesere til å tro at Noise-basert autorisasjon er aktiv. Rydd opp eller implementer den faktisk.

---

## Positive observasjoner

Ikke alt er galt — flere ting er gjort riktig:

- **JWT-validering** i `SessionContext` avviser nå manglende/ugyldig token (ingen tillit til `X-Account-Id`-headere lenger, tross misvisende docstring).
- **Profil↔konto-eierskap** verifiseres i `SessionContext.load_current_profile/1`.
- **Webhook-tokens** genereres med `:crypto.strong_rand_bytes(32)` — god entropi.
- **OTP-kode-sammenligning** bruker `Plug.Crypto.secure_compare/2`.
- **Rate limiting** finnes på auth-challenge og meldinger (Hammer).
- **CSRF/secure headers** er på plass for browser-pipeline.
- **Media-opplasting** har størrelsesgrense (50 MB) og genererer UUID-baserte objektnøkler.

---

## Prioritert utbedring

1. **SEC-2 + SEC-3 + SEC-5** — Innfør sentral medlemskaps-plug og kanal-/eierskaps-sjekker. Dette er den største risikoen og bør fikses samlet.
2. **SEC-1 + SEC-4** — Bytt til `:crypto.strong_rand_bytes` for OTP og MAC/lengre koder + forsøkstelling.
3. **SEC-6** — Konstant-tid-sammenligning av bot-secret.
4. **SEC-7** — Flytt secrets ut av versjonskontroll ([#193](https://github.com/mikalv/msgr/issues/193)).
5. **SEC-8** — Rydd opp i no-op autorisasjonsopsjon.

Alle funn bør re-verifiseres i en uavhengig ekstern revisjon ([#196](https://github.com/mikalv/msgr/issues/196)) før produksjonslansering.
