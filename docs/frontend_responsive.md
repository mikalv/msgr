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

## Tester

Widget-testen `home_page_test.dart` dekker brytepunktene slik at fremtidige endringer holder layouten responsiv.
