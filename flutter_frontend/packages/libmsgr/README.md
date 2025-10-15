# libmsgr

`libmsgr` is the shared Dart library that powers the Flutter client. It
provides repositories, models and helper services for interacting with the
msgr backend from multiple front-ends.

## Features

- Bootstrapping helpers through the `LibMsgr` singleton which wires up secure
  storage, device information and the encrypted local database.
- `RegistrationService` and `AuthRepository` that implement the OTP based sign
  in flow used by the native clients.
- Repositories for rooms, conversations, profiles and messages backed by Drift
  and HTTP APIs.
- Data models for all messaging domain entities with `fromJson` factories.
- Works together with the pure Dart [`libmsgr_cli`](../libmsgr_cli) package for
  command line smoke tests and automation.

## Getting started

Include the package and initialise the singleton before accessing any
repositories:

```dart
final lib = LibMsgr();
lib.secureStorage = MySecureStorage();
lib.sharedPreferences = MySharedPreferences();
lib.deviceInfoInstance = MyDeviceInfo();
await lib.bootstrapLibrary();
```

For more background on the public API see [`docs/libmsgr_api.md`](../../docs/libmsgr_api.md).

## CLI usage

Command line automation now lives in the sibling
[`libmsgr_cli`](../libmsgr_cli) package so the tooling can depend solely on the
pure Dart `libmsgr_core` abstractions. To run the integration flow locally:

```bash
cd flutter_frontend/packages/libmsgr_cli
dart pub get
dart run bin/msgr.dart integration-flow
```

Pass `--json` (or `-j`) to emit machine readable output that includes the team
host, access token and identifiers for the created resources. Use `--help` to
inspect the available options.

The integration test suite (`integration_tests/test_cli_flow.py`) exercises the
same command with `--json` to provision fresh accounts on demand.

## Additional information

- Repository: https://github.com/msgr-no/flutter_client
- License: MIT (see repository root)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
