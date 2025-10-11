# Responsive Flutter shell

Denne notatfilen beskriver hvordan den nye responsive hjemmeskjermen i Flutter-appen er strukturert.

## Brytepunkt

| Navn | Bredde | Layout |
| ---- | ------ | ------ |
| Kompakt | < 900 px | Enkeltkolonne med kategori-velger og chatkort |
| Nettbrett | 900-1279 px | To kolonner med innboks-panel og samtalekort |
| Desktop | >= 1280 px | Tre kolonner med gradient-sidefelt, innboks og samtalekort |

## Oppbygning

- `_HomeSidebar` gir et gradientpanel med handlinger for ny samtale, invitasjon og innstillinger.
- `_HomeInboxPanel` viser søkefelt, filterchips og lister over rom og samtaler.
- `_HomeActionStrip` tilbyr raske snarveier (meny, innstillinger, invitasjon, nytt rom, ny samtale).
- `_HomeChatPanel` legger inn `ChatPage` i et kort med avrundede hjørner og skygge på større skjermer.
- `ChatPage` bruker det modulære chat-UI-kitet med kanalpanel, trådvisning og tilkoblingsbanner. På smale skjermer rendres kanallisten over tråden.
- Trådvisningen viser typing-indikator, reaksjonsaggregat og festede meldinger
  gjennom dedikerte notifiers (`TypingParticipantsNotifier`,
  `ReactionAggregatorNotifier`, `PinnedMessagesNotifier`) og widgetene
  `TypingIndicator` og `PinnedMessageBanner`.
- Watcher-panelet lytter på `conversation_watchers`-strømmen og skjuler
  inaktive seere etter den konfigurerte TTL-en via
  `Chat.watch_conversation`-notifieren.

## Tester

Widget-testen `home_page_test.dart` dekker brytepunktene slik at fremtidige endringer holder layouten responsiv.
`chat_view_model_offline_test.dart` dekker offline fallback for chatten og bekrefter at hurtigbufferte meldinger brukes når nettverket forsvinner.
