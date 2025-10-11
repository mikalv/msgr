# UI-kit stories og demokjøring

Dette dokumentet viser hvordan de nye modulære chat-komponentene kan testes isolert.

## Kanal- og tråddemo

`ChannelListPage` ligger under `lib/ui/pages/channel_list_page.dart` og kombinerer `ChatChannelList`, `ChatThreadViewer` og `ChatReactionPicker` med profilbasert tematisering.

Kjør siden direkte:

```bash
flutter run -d chrome lib/ui/pages/channel_list_page.dart
```

Siden inneholder dummyprofiler, nærværsindikatorer og en reaksjonsvelger som matcher temaet til hver profil.

## ChatComposer-standalone

For å teste `ChatComposer` isolert kan man endre `main.dart` midlertidig til å returnere `const ChatComposerDemo()` fra `lib/features/chat/chat_composer_demo.dart`.

```bash
flutter run -d chrome lib/features/chat/chat_composer_demo.dart
```

Demo-widgeten monterer komponisten i et enkelt scaffold og logger stateendringer (emoji, kommandoer, vedlegg og taleopptak) til debug-konsollen.

## Offline-cache demonstrasjon

Integrasjonstesten `test/features/chat/state/chat_view_model_offline_test.dart` kan kjøres for å bekrefte at Hive/Sembast-cache benyttes når nettverket er utilgjengelig:

```bash
flutter test test/features/chat/state/chat_view_model_offline_test.dart
```

Testen spoofer et nettbrudd, laster meldinger fra cache og sikrer at `ChatViewModel` viser offline-banneret.
