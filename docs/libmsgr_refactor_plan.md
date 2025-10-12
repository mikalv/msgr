# libmsgr Refactor Plan

## Goals
- Split the current `libmsgr` package into UI-dependent and UI-agnostic layers.
- Provide a pure Dart core that exposes networking, auth, and domain models without depending on Flutter plugins (`shared_preferences`, `sqflite`, etc).
- Ensure CLI tooling and future service integrations can reuse the core without dragging in Flutter.
- Maintain backwards compatibility for the Flutter app during the migration.

## Current Pain Points
- `libmsgr` imports Flutter-only plugins, preventing execution with `dart` alone.
- CLI tools and integration tests break when `dart:ui` is unavailable.
- Storage and device abstractions are tightly coupled to Flutter implementations.
- Configuration is scattered, making it hard to swap environments when reusing the library.

## Target Architecture
- **libmsgr_core (new package)**: pure Dart (no Flutter). Contains:
  - API clients and DTOs.
  - Auth/registration services with abstract persistence + device interfaces.
  - Environment/config helpers.
- **libmsgr (existing package)**:
  - Depends on `libmsgr_core`.
  - Provides Flutter-specific adapters (secure storage, shared preferences, Drift DB).
  - Re-exports the high-level API consumed by the Flutter app.
- **CLI**:
  - Depends directly on `libmsgr_core`.
  - Supplies in-memory adapters for storage/device context.
  - Will migrate into a dedicated package (`libmsgr_cli`) with pluggable persistence.

## Workstreams
1. **Bootstrap Core Package**
   - Create `packages/libmsgr_core` with minimal `pubspec`.
   - Define base folder structure (`lib/src/...`, `lib/libmsgr_core.dart`).
   - Copy/port shared constants & plain Dart utilities from `libmsgr`.

2. **Define Interfaces**
   - Extract abstract contracts for secure storage, shared prefs, device info, and persistence.
   - Move contracts + default in-memory implementations into `libmsgr_core`.

3. **Move Services**
   - Relocate auth/registration repositories, HTTP clients, and models to the core.
   - Update imports in Flutter layer to reference the new package.

4. **Adapter Layer in libmsgr**
   - Provide concrete implementations of the abstract interfaces using Flutter plugins.
   - Update `LibMsgr` bootstrap to compose the core with adapters.

5. **CLI Updates**
   - Switch CLI to depend on `libmsgr_core` only.
   - Ensure it wires in the in-memory adapters without requiring Flutter.
   - Extract CLI into `libmsgr_cli` package with file-backed persistence for debugging.
   - Expose shared entrypoints for integration tests.

6. **Testing & CI**
   - Add pure Dart tests for core.
   - Update existing Flutter tests to account for new package boundaries.
   - Adjust CI scripts to run `dart test` for the core package and `flutter test` for UI.

## Migration Sequence
1. Land skeleton for `libmsgr_core` (package structure, pubspec, README).
2. Introduce shared interfaces + minimal functionality (constants, logging bootstrap).
3. Move auth & registration services; update Flutter package to import from core.
4. Refactor CLI to target core; verify `dart run` works.
5. Scaffold `libmsgr_cli` package (pubspec, README, binary entrypoint).
6. Implement file-backed storage provider (yaml/json) for CLI debugging.
7. Incrementally migrate the rest of the data layer (repositories, models, cache adapters).
8. Remove redundant Flutter-only dependencies from `libmsgr`.
9. Final clean-up: update docs, ensure version bumps, align build scripts.

## Risks & Mitigations
- **Breaking changes**: Introduce adapters and maintain compatibility until all consumers migrate.
- **Circular dependencies**: Establish clear direction (`libmsgr_core` <- adapters <- Flutter components).
- **CI breakage**: Update workflows once new package added; run both dart and flutter tests locally first.
- **Documentation drift**: Update `docs/libmsgr_api.md`, CLI README, and onboarding guides as steps land.

## Next Steps
1. Complete auth/services migration by moving the remaining repositories (message/profile/etc.) into `libmsgr_core`.
2. Switch CLI integration tests to invoke `packages/libmsgr_cli` directly and remove the legacy `tool/` proxy once stable.
3. Gradually migrate persistence/cache adapters (Drift, Redux wiring) to use the new abstractions and delete Flutter-only shims.
