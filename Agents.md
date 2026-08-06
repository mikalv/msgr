# Agent Notes

- **Key norms:**
  - Prefer `rg`/`ripgrep` for search; always set `workdir` on shell commands.
  - Use `apply_patch` for single-file edits (no parallel tool use).
  - Avoid non-ASCII unless file already uses it; keep comments concise.
  - Never revert user changes or run destructive git commands unless instructed.
  - Skip plan tool for trivial work; otherwise keep multi-step plans updated.
  - Every meaningful change must be reflected in `CHANGELOG.md`.
  - Keep files small: refactor if any file approaches 2 000 lines (ideally <1 000 lines / 1 000 characters per file); split logic rather than letting files grow. Use subdirectories if needed.
  - Aim for “medium” documentation density: brief but useful doc comments on non-trivial functions, modules, and public APIs.
  - Application code and public documentation must remain in English, even if the request comes in Norwegian (translate as needed).
  - Keep agents.md updated with information considered critical to know
  - It's better with big changes rather than "should I continue?" for each little detail.
  - Always check for syntax error / compile errors
  - Tests when possible
  - Source code files should have a top comment explaining what the file does, this should be kept updated
  - Be very careful to delete or remove files and directories

Use this file as a quick refresher before diving back into the repo.

## All programming languages

* Indent is defaulted to 2 spaces. Use this unless file use other indent from before. New files is always 2 spaces.
* CamelCase over underscore_functions.

## Python

* Indent is defaulted to 2 spaces.
* `uv` er dependency mgmt verktøyet vi skal bruke

## Rust

* Use `dbg!` for debugging
* When you really have to mark a TODO, don't do it as a comment but as `todo!("Whaterver")`

## Dart

* Always check code with analyze

## TODOs

OM du MÅ lage TODOs, dokumenter også alle til `TODO.md` så vi ikke glemmer av de. Men prøv å unngå de i det store og hele. vi liker å gjøre alt skikkelig med en gang.

## AI skeptisism

Do not place or leave AI traces in this repository. I would lovely give you credit, but the software wouldn't be trusted by the public then.

## Windows

Use powershell for commands, never cmd.exe.

## Cursor Cloud specific instructions

Scope: the cloud VM is provisioned for the **Elixir/Phoenix backend** (`backend/`), which is
the core product. The Flutter app, Rust gateway, and Go/Python bridges are not set up here.
General backend docs live in `backend/README.md` and `docs/backend_setup.md`; the notes below
only cover cloud-specific, non-obvious gotchas.

### Toolchain (asdf)
- Erlang/Elixir are managed by asdf. This repo requires **Elixir 1.16.2 / OTP 26.2** (what CI
  uses). The committed `backend/.tool-versions` pins 1.19.1/OTP 28, which does **not** compile
  the project (the `castle`/`n` dependency derives the release version from `git describe`, and
  with no semver tags Mix rejects the bare short SHA as an invalid `Version`). The environment
  forces the working toolchain via `ASDF_ERLANG_VERSION=26.2.5` and
  `ASDF_ELIXIR_VERSION=1.16.2-otp-26` (exported in `~/.bashrc`). Do not `cd backend` and assume
  the pinned 1.19.

### Services
- Only **PostgreSQL** is a hard boot dependency; Redis/StoneMQ/MinIO/ClamAV are optional or
  best-effort in dev (MinIO `econnrefused` warnings at boot are harmless when object storage is
  down). Start Postgres each session: `sudo pg_ctlcluster 16 main start` (or
  `sudo service postgresql start`). The backend connects as `postgres`/`postgres` on
  `localhost:5432`; dev DB `msgr_dev`, test DB `msgr_test`.

### Run / DB setup
- `mix setup` is **broken** here — its `cmd --app auth_provider mix setup` recursion hits the
  git-version error above. Do the steps manually: `MIX_ENV=dev mix ecto.create` then
  `mix ecto.migrate` (the app also auto-runs migrations on boot). Test DB:
  `MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate`.
- Dev server (from `backend/`): `PHX_LISTEN_IP=127.0.0.1 PORT=4000 SWOOSH_LOCAL_ADAPTER=true MIX_ENV=dev mix phx.server`.
  With `SWOOSH_LOCAL_ADAPTER=true`, OTP emails go to the in-memory mailbox at
  `http://localhost:4000/dev/mailbox` (JSON: `/dev/mailbox/json`). Health: `/health`,
  LiveDashboard: `/dev/dashboard`.
- OTP/account flow: `POST /api/v1/auth/challenge {channel,identifier}` → read code from the
  mailbox → `POST /api/v1/auth/verify {challenge_id,code}` → creates the account and returns JWT
  access/refresh tokens.

### Tests / lint
- Prometheus binds port **9568**. If the dev server is running, `mix test` fails with
  `:eaddrinuse` — run tests with `PROMETHEUS_ENABLED=false` (or stop the dev server first).
- Pre-existing on this branch: `apps/msgr/test/messngr/accounts/contact_conversation_flow_test.exs`
  has a compile error (`^message.id` in a pattern) that blocks the whole `apps/msgr` suite; run
  other files/apps individually until it is fixed.
- Lint: `mix format --check-formatted`, `mix credo --strict`, `mix lint`. Some files are currently
  unformatted and credo --strict reports many findings (pre-existing repo state).

