# Historikkstrømming og watcher-flyt

Denne notatet beskriver arbeidsplanen for å levere cursor-basert historikk og watcher-APIer på tvers av backend, PubSub og Flutter.

## Backend
- Utvid `Messngr.Chat` med helper-funksjoner (`after_id/2`, `around_id/2`, `has_more/2`) slik at REST og WebSocket kan dele samme logikk.
- Implementer `list_conversations/2` som kombinerer siste melding, `unread_count` (midlertidig beregnet), samt `before_id`/`after_id`-cursorer.
- Oppdater `MessageController` og `ConversationController` til å returnere cursor-meta og nye watcher-endepunkt.
- Legg til kanalhandlere for `message:sync`, `conversation:watch`, `conversation:unwatch` og broadcast backlog-sider ved ny tilkobling.
- Skriv ExUnit-tester for paginering, watchers og PubSub-varslinger.

### Status (Implementert)
- `Messngr.Chat.list_messages/2` returnerer nå både meldingsliste og cursor-meta (`before_id`, `after_id`, `around_id`, `has_more`), og `Chat.broadcast_backlog/2` sprer resultatet over PubSub.
- `Messngr.Chat.list_conversations/2` leverer siste melding og midlertidig `unread_count` for hver deltaker, med egne cursorer for paginering.
- REST-endepunktene `/api/conversations` og `/api/conversations/:id/messages` serialiserer cursor-meta, mens `ConversationChannel` eksponerer `message:sync`, `conversation:watch` og `conversation:unwatch` med Presence-sporing.
- ExUnit- og Channel-tester dekker cursorene, backlog-broadcast og watcher-flyt.

## Flutter
- Refaktorer `ChatViewModel` til å støtte flere kanaler, lazy loading og cursor-baserte fetches.
- Introduser `ChannelListViewModel` under `lib/features/chat/state/` og oppdater `ChatTimeline` for prepend/pagination.
- Dekk med widget- og integrasjonstester for scrollede sider og watchers.

## Dokumentasjon og changelog
- Oppdater `CHANGELOG.md` og relevante arkitektur-dokumenter (f.eks. `docs/bridge_architecture.md`) med ny historikkstrømming og watcher-flyt.
- Dokumenter teststrategien for cursorer i både backend og Flutter.

## Neste steg
1. Implementer backend-helperne og nye API-svarfelter.
2. Etabler PubSub-backlog for watchers og bekreft med ExUnit.
3. Refaktorer Flutter state + UI, oppdatér tester og dokumentasjon.
