# Messngr Flutter-klient

Denne klienten er bygget i Flutter og kobler seg mot Phoenix-baserte backend-APIer.

## Forutsetninger

- [Flutter](https://docs.flutter.dev/get-started/install) 3.16 eller nyere
- En backend som eksponerer Messngr-APIet (se `docker-compose.yml` for et raskt
  Phoenix/Postgres-oppsett)

## Konfigurere backend-adresse

Klienten bruker nå `BackendEnvironment` for å samle all konfigurasjon av
serverens URL. Du kan endre bakenden uten å endre kildekoden ved å bruke
`--dart-define`-flagg når du kjører `flutter run` eller `flutter build`:

```bash
flutter run \
  --dart-define=MSGR_BACKEND_SCHEME=http \
  --dart-define=MSGR_BACKEND_HOST=192.168.1.100 \
  --dart-define=MSGR_BACKEND_PORT=4000 \
  --dart-define=MSGR_BACKEND_API_PATH=api
```

Bare parametrene du oppgir blir overstyrt – resten faller tilbake til
standardverdiene (`http://localhost:4000/api`). Under kjøring kan du også
opprette en midlertidig override i kode via
`BackendEnvironment.instance.override(host: '10.0.2.2');` dersom du bygger egne
debugverktøy.

For engangstester kan du også sette kun hosten:

```bash
flutter run --dart-define=MSGR_BACKEND_HOST=10.0.2.2
```

## Starte applikasjonen

```bash
flutter pub get
flutter run
```

På web kan du starte en utviklingsserver med:

```bash
flutter run -d chrome
```

## Nyttige kommandolinjealias

- `flutter test` – kjører enhetstester og widgettester
- `flutter format .` – formatterer kildekoden

Se også `lib/config/backend_environment.dart` for flere detaljer rundt
konfigurasjonen av backendtilkoblingen.

## Loggstrømming til OpenObserve

Klienten kan sende `package:logging`-meldinger direkte til OpenObserve når
Docker-miljøet er startet. Aktivér funksjonen med `--dart-define`-flaggene:

```bash
flutter run \
  --dart-define=MSGR_LOG_ENABLED=true \
  --dart-define=MSGR_LOG_ENDPOINT=http://localhost:5080 \
  --dart-define=MSGR_LOG_STREAM=flutter \
  --dart-define=MSGR_LOG_USERNAME=root@example.com \
  --dart-define=MSGR_LOG_PASSWORD=Complexpass#123
```

Standardverdiene matcher docker-compose-oppsettet (`root@example.com` /
`Complexpass#123`). Under kjøring kan du endre strømmen eller deaktivere logging
med `LoggingEnvironment.instance.override(enabled: false);`.

## Snapchat Camera Kit

Messngr kan bruke [Snapchat Camera Kit](https://developer.snap.com/docs/camera-kit/)
for å tilby linser når brukere tar bilder eller video i chatte-komponisten.
Funksjonen er som standard deaktivert og må konfigureres med Snapchat-nøkler
via `--dart-define`.

Tilgjengelige parametere:

```
MSGR_CAMERA_KIT_ENABLED=true
MSGR_CAMERA_KIT_APPLICATION_ID=<Snapchat application id>
MSGR_CAMERA_KIT_API_TOKEN=<Camera Kit API token>
MSGR_CAMERA_KIT_LENS_GROUP_IDS=<kommaseparert liste med lens-grupper>
```

Eksempel på oppstart med Camera Kit aktivert:

```
flutter run \
  --dart-define=MSGR_CAMERA_KIT_ENABLED=true \
  --dart-define=MSGR_CAMERA_KIT_APPLICATION_ID=com.example.myapp \
  --dart-define=MSGR_CAMERA_KIT_API_TOKEN=sn-xxxxxxxx \
  --dart-define=MSGR_CAMERA_KIT_LENS_GROUP_IDS=abcd1234,efgh5678
```

### Native oppsett

- **Android:** avhenger av `com.snap.camerakit:support-camera-activity`. Legg inn
  Camera Kit API token og lens-grupper via miljøvariablene ovenfor.
- **iOS:** Pod-avhengighetene `SCSDKCameraKit` og `SCSDKCameraKitReferenceUI`
  må installeres. Kjør `pod install` i `ios/` etter at hemmelighetene er lagt
  inn. Sørg også for at `Info.plist` inneholder oppdaterte beskrivelser for
  kamera-, mikrofon- og bildebibliotekstilgang.
