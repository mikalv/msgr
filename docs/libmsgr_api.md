# libmsgr API overview

This document summarises the parts of the `libmsgr` package that are currently
used by the Flutter application, the CLI utilities and the integration tests.
It focuses on the public surface available from `package:libmsgr/libmsgr.dart`
and explains how the building blocks fit together when bootstrapping a client
and carrying out an authentication flow.

## Bootstrapping the SDK

The `LibMsgr` singleton coordinates all services exposed by the library. Before
invoking any of the repositories or the `RegistrationService`, callers must
provide platform adapters and call `bootstrapLibrary()`:

```dart
final lib = LibMsgr();
lib.secureStorage = MySecureStorage();
lib.sharedPreferences = MySharedPreferences();
lib.deviceInfoInstance = MyDeviceInfo();
await lib.bootstrapLibrary();
```

`LibMsgr` initialises the key manager, the encrypted database and prepares the
repository factory. The getters on the singleton expose lazily constructed
instances such as:

- `authRepository` – convenience helpers around `RegistrationService` that
  offer a repository style interface.
- `repositoryFactory` – creates repositories for rooms, conversations and
  messages backed by the Drift database.
- `databaseService` – access to the encrypted SQLite database used by the
  offline cache.

## Authentication helpers

Authentication is performed through `RegistrationService`, which wraps the HTTP
endpoints provided by the backend:

- `maybeRegisterDevice()` registers the current device with the authentication
  service if it has not been registered yet. Device and application metadata can
  be injected when running outside of Flutter.
- `requestForSignInCodeEmail()` and `requestForSignInCodeMsisdn()` start an OTP
  challenge. When running against development infrastructure the response
  contains a `debugCode` field that can be used by automated tests.
- `submitEmailCodeForToken()` and `submitMsisdnCodeForToken()` finish the
  challenge and return a `User` model containing access tokens.
- `selectTeam()`, `createNewTeam()` and `createProfile()` allow the caller to
  bootstrap a fresh team and user profile after sign-in.

The `AuthRepository` class re-exposes these helpers and keeps the API familiar
for Redux middleware that interacts with the rest of the Flutter application.

## Domain repositories

The following repositories are exported by the package and are responsible for
fetching and persisting domain entities:

- `ConversationRepository` – fetches conversations and allows creating new
  threads.
- `MessageRepository` – posts and retrieves conversation messages.
- `ProfileRepository` – works with user profiles and their presence.
- `RoomRepository` – handles private rooms and their memberships.

All repositories follow the same pattern: they issue network requests using the
HTTP clients configured inside `LibMsgr` and persist responses to the local
Drift database so that the Redux stores in the Flutter client can operate on a
consistent cache.

## Models

Key data structures exposed to consumers:

- `User`, `Profile`, `Team` – describe the authenticated actor, team metadata
  and the active profile within the team.
- `Conversation`, `Room`, `Message`, `Attachment` – entities representing the
  messaging domain that are serialisable to and from JSON.
- `AuthChallenge` – response returned by the OTP challenge endpoints.

Each model can be constructed from JSON via a `fromJson` factory, making them
suitable for use both in Flutter and in command line tools.

## Command line utilities

CLI tooling now lives in the `packages/libmsgr_cli` package. The legacy
`tool/msgr_cli.dart` entrypoint forwards to the new implementation so existing
integration tests keep working.

`libmsgr_cli` boots the pure Dart core (`libmsgr_core`), persists state in a
local directory and exposes an `integration-flow` command that registers a
device, completes the OTP auth flow, creates a team and ensures a profile
exists. See `packages/libmsgr_cli/README.md` for usage instructions.
