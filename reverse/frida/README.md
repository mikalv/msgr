# Frida Toolkit Overview

Denne katalogen inneholder scripts og verktøy som hjelper oss å instrumentere offisielle Android-klienter med Frida. Målet er å dumpe protobuf- og JSON‑payloads, WebSocket‑trafikk og krypteringsnøkler direkte fra klientens minne.

### Struktur
```
reverse/frida/
├── android/
│   ├── scripts/              # Frida JS-moduler (OkHttp, WebSocket, JNI, TLS)
│   ├── tools/                # Python helpers for automatisering
│   └── examples/             # Output-eksempler, loggutdrag
└── README.md                 # Denne filen
```

Se `reverse/docs/frida_android.md` for full guide til oppsett i emulator, kjøring av scripts og nyttige tips. Start med:
- `android/scripts/hook_okhttp.js` for HTTP-request/response payloads.
- `android/scripts/hook_websocket.js` for WebSocket frames.
- `android/scripts/hook_protobuf.js` for å se hvilke protobuf-klasser som serialiseres.
- `android/tools/setup_android_sdk.(sh|ps1)` for å installere Android SDK/emulator på macOS/Linux/Windows.
- `android/tools/setup_frida_env.(sh|ps1)` for å hente Frida CLI + frida-server.
- `android/tools/frida_dump.py` for å automatisk lagre `send()`-payloads til JSONL.
