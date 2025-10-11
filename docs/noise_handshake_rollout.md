# Noise-handshake rollout

Denne endringen gjør Noise-handshake obligatorisk før OTP-verifisering og videre
REST-kall kan lykkes. Dokumentet beskriver hvordan klienter skal utveksle
handshake-data, hvilke nye headere som må sendes og hvordan funksjonen kan
rulles ut kontrollert.

## 1. Handshake + OTP

1. Etabler en Noise NX/IK-handshake mot backend. Når serveren svarer med en
   ferdig `Session`, må klienten lagre:
   - `session_id` (`Session.id/1` i backend).
   - Attestasjons-signaturen: HMAC-SHA256 av handshake-hash med den utstedte
     sesjonstokenen (`Messngr.Noise.Handshake.encoded_signature/1`).
   - Klientens statiske nøkkel i URL-safe Base64 (`Messngr.Noise.Handshake.device_key/1`).
2. Send OTP-challenge som tidligere, men inkluder `device_id` lik
   Base64-varianten av den statiske nøkkelen.
3. Når OTP-koden postes til `/api/auth/verify` **må** klienten sende:
   ```json
   {
     "challenge_id": "…",
     "code": "123456",
     "noise_session_id": "…",
     "noise_signature": "…",
     "last_handshake_at": "2024-10-05T08:45:32Z"
   }
   ```
4. Responsen inneholder `noise_session.token` som må legges på alle videre REST
   og WebSocket-kall:
   ```http
   Authorization: Noise <token>
   ```

## 2. Telemetri

Handshake- og tokensteg publiserer Telemetry-events for å følge suksessrate og
feilkoder:

- `[:messngr, :noise, :handshake, :start|:stop|:exception]`
- `[:messngr, :auth, :noise, :handshake, :success|:failure]`
- `[:messngr, :noise, :token, :issue|:register|:verify]`
- `[:messngr, :noise, :token, :verify, :failure]`

Eventene kan kobles på eksisterende Prometheus/Sentry-pipelines.

## 3. Feature-flag og rollout

Funksjonen styres av `Messngr.FeatureFlags` og er standard **av**. For å aktivere
eller deaktivere i produksjon brukes mix-tasken:

```bash
mix rollout.noise_handshake --enable
mix rollout.noise_handshake --disable
```

Det er trygt å aktivere i staging først. Telemetri gir løpende innsikt i hvor
mange klienter som fortsatt mangler handshake-headeren.

## 4. Klientkrav

- Klienter må håndtere både handshake og OTP i samme kontrollflyt.
- Tokenet fra `noise_session` lagres som kortlivet bearer-token og må sendes i
  `Authorization`-headeren for hver HTTP-forespørsel og ved WebSocket connect.
- Dersom backend svarer med `noise_handshake`-feil må klienten restarte
  handshaken og be om ny OTP.

## 5. Tilbakerulling

Skulle utrulling feile kan flagget skrus av (`--disable`). Eksisterende
sesjoner forblir gyldige og Telemetry vil vise feilkodene som trigget
rollbacken.
