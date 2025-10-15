# libmsgr_cli

Command line utilities that exercise the msgr backend through the shared
`libmsgr_core` package. The CLI is intended for smoke testing and local
integrations without pulling in any Flutter-only dependencies.

Persistent storage is backed by simple JSON/Text files under the CLI state
directory (defaults to `~/.msgr_cli`).

## Usage

```
cd flutter_frontend/packages/libmsgr_cli
dart pub get
dart run bin/msgr.dart integration-flow --json
```

Pass `--help` to inspect the available commands and flags. All state (device
registration, cached tokens) is stored under `~/.msgr_cli` unless a custom
`--state-dir` is provided.

See `docs/libmsgr_refactor_plan.md` for the complete migration roadmap.
