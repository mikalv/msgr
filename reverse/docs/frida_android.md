# Frida Playbook for Android Clients

Målet er å få raskt innsyn i hvordan Android-klienten snakker med backend (f.eks. Snapchat, Instagram), og hvilke protobuf / krypteringslag som brukes. Denne guiden viser hvordan du setter opp et Frida-miljø i emulator, hooker relevante metoder og dumper payloads.

## 1. Forberedelser
- **macOS / Linux**: Kjør `reverse/frida/android/tools/setup_android_sdk.sh` for å hente Android SDK, emulator, platform-tools, osv.
- **Windows**: Bruk `reverse/frida/android/tools/setup_android_sdk.ps1` (PowerShell) for samme oppsett.
- **Frida CLI + server**: `setup_frida_env.sh` (macOS/Linux) eller `setup_frida_env.ps1` (Windows) installerer `frida`/`frida-tools` og laster ned `frida-server` som matcher din ABI.
- APK for målappen (nedlastet fra Play Store via emulator eller tredjeparts verktøy).

### Kjapp start
```bash
# macOS / Linux
./reverse/frida/android/tools/setup_android_sdk.sh
./reverse/frida/android/tools/setup_frida_env.sh

# Windows (PowerShell)
pwsh -File .\reverse\frida\android\tools\setup_android_sdk.ps1
pwsh -File .\reverse\frida\android\tools\setup_frida_env.ps1
```

Installer Frida CLI-verktøy (gjøres automatisk av `setup_frida_env.*`, men kan kjøres manuelt):
```bash
pip install --user frida-tools frida
# eller via brew:
brew install frida
```

## 2. Start Android-emulator
```bash
$ANDROID_HOME/emulator/emulator -avd Pixel_6_API_33 -writable-system -no-snapshot
```

Aktiver `adb root` og remount slik at vi kan pushe Frida-server:
```bash
adb root
adb remount

adb push ./reverse/frida/bin/frida-server-*-android-* /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
```

Start Frida-server i emulatoren (la terminal stå åpen):
```bash
adb shell "/data/local/tmp/frida-server"
```

## 3. Installer og konfigurer målappen
1. Installer APK-en via `adb install app.apk` eller Google Play i emulatoren.
2. Logg inn med testkonto.
3. Finn prosessnavnet (bruk `adb shell ps | grep <package>`).

## 4. Kjøre Frida-script
Strukturen ligger under `reverse/frida/android/`. Hvert script er en Frida modul (`.js`) som hooker en spesifikk klasse eller native funksjon.

### Eksempel: dump protobuf payloads i OkHttp
`reverse/frida/android/scripts/hook_okhttp.js`:
```javascript
Java.perform(() => {
  const RequestBuilder = Java.use('okhttp3.Request$Builder');
  const RealCall = Java.use('okhttp3.RealCall');

  RealCall.execute.implementation = function () {
    const response = this.execute();
    const request = this.request();

    const url = request.url().toString();
    const method = request.method();
    const body = request.body();

    send({ type: 'http-request', url, method });

    if (body) {
      try {
        const Buffer = Java.use('okio.Buffer');
        const buffer = Buffer.$new();
        body.writeTo(buffer);
        const bytes = buffer.readByteArray();
        send({
          type: 'http-body',
          url,
          length: bytes.length,
          base64: Java.use('android.util.Base64')
            .encodeToString(bytes, 2),
        });
      } catch (error) {
        send({ type: 'error', stage: 'request-body', message: error.toString() });
      }
    }
    return response;
  };
});
```

Kjør skiptet:
```bash
frida -U -f com.snapchat.android -l reverse/frida/android/scripts/hook_okhttp.js --no-pause
```

Frida CLI viser `send()`-payloads. Lagre output lokalt:
```bash
frida -U -f com.snapchat.android -l ... --no-pause --output dump.jsonl
```

### WebSocket hook (SignalR / gRPC)
`hook_websocket.js` intercept-er `okhttp3.internal.ws.RealWebSocket`. Scriptet fanger `sendMessage()` (utgående) og `WebSocketReader.readMessageFrame()` (innkommende) for å hente binære frames før kryptering. Du kan utvide med base64-dekoding for gRPC ved å parse de loggede payloadene.

### Protobuf introspection
`hook_protobuf.js` hooker `GeneratedMessageLite.toByteArray`, `GeneratedMessageLite.parseFrom` og `MessageLite.toByteString`. Resultat:
- Klassenavnet på proto-objektet logges sammen med base64-encoded bytes.
- Stacktraces gjør det enklere å se hvilken feature som trigget serialisering/deserialisering.
- Pass output til `client-recorder-blobs` for å diff-e payloadene og finne nye felt.

> Tips: Kombiner `hook_okhttp.js` og `hook_protobuf.js` i samme Frida sesjon for å mappe HTTP-endpoints til proto-klasser.

### JNI / Native kryptering
For libs som bruker C++ kryptering, finn funksjonsadresse med:
```bash
frida-trace -U -i "_ZN12CryptoModule12encryptProtoE" com.snapchat.android
```

Eller bruk `Module.enumerateExports('libxyz.so')` og hook med `Interceptor.attach`.

## 5. Tips for reverse-engineering
- Kombiner Frida dump med recorderens ressurslagring for å matche JS vs. Android protokoller.
- Bruk `jadx` til å finne relevante metoder (søk på `protobuf`, `OkHttpClient`, `WebSocketListener`).
- Tilpass Frida scriptet til e.g. `Moshi` eller `Gson` serialization hooks for å få ut JSON før obfuskering.
- For Snap, se etter `com.snapchat.client.grpc` klasser. Hook `build()` og `parseFrom()` på genererte protobuf-objekter.
- Bruk `frida --codeshare` for å hente eksisterende script som baseline.

## 6. Automatisert logging
Bruk `reverse/frida/android/tools/frida_dump.py` for å kjøre script, samle JSONL og analysere:
```bash
python reverse/frida/android/tools/frida_dump.py \
  --package com.snapchat.android \
  --script reverse/frida/android/scripts/hook_okhttp.js \
  --output captures/android-okhttp.jsonl
```

Scriptet leser `send()`-payloads fra Frida og lagrer dem med tidsstempel.

## 7. Sikkerhet og hygiene
- Ikke bruk sanntidskontoer; lag testkonto.
- Kjør emulatoren i nettverksisolert miljø.
- Husk at Frida kan trigge anti-tamper; vurder `objection patchapk` for bypass, eller `magisk` hvis fysisk device.

## 8. Videre arbeid
- Legg til script for TLS key logging (`SSL_write`/`SSL_read` hooks).
- Integrer Frida output med eksisterende analyzer (`client-recorder-blobs`) for å identifisere nye protobuf-definisjoner.
- Dokumenter bypass av Play Integrity / SafetyNet dersom appen slår seg av med Frida aktiv.

## 9. Neste steg
- Skriv scripts som dumper `MessageNano`/`GeneratedMessageLite` callsites for å få protobuf definisjon.
- Lag en `frida-trace` preset (`reverse/frida/android/tools/trace.sh`) som fokuserer på `okhttp3.*` og `com.snapchat.client.grpc.*`.
- Utforsk `objection` patching for å disable root detection og SSL pinning før Frida startes.
- Implementer `hook_tls_keys.js` som logger `SSL_write`/`SSL_read` og eksporterer nettverksnøklene til `SSLKEYLOGFILE` for Wireshark-dekryptering.
