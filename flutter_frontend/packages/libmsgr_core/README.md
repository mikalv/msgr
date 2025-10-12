# libmsgr_core

`libmsgr_core` is the UI-agnostic core for interacting with the msgr backend.
It exposes pure Dart services, API clients and models that can be consumed from
both Flutter applications and command line tooling without pulling in Flutter
plugins or `dart:ui`.

Status: **WIP** – the package currently contains scaffolding and will be filled
out as we migrate functionality from the existing `libmsgr` package.

## Getting started

```
dart pub get
dart test
```

Add `libmsgr_core` as a dependency in other packages and provide the platform
specific adapters (secure storage, persistence, device info) within the
consumer.

## Roadmap

- Extract shared constants and request helpers from `libmsgr`.
- Define abstract interfaces for storage, preferences and device information.
- Port the authentication and registration flows to the core.
- Update the Flutter package to depend on this core and supply adapters.
- Switch CLI tooling to depend solely on `libmsgr_core`.

See `docs/libmsgr_refactor_plan.md` in the repository root for migration
details.
