# CI, coverage, and pending test suites

Developer runbook for GitHub Actions (`.github/workflows/ci.yaml`), ExCoveralls,
and the parked `**/test/pending_*` suites. Complements `INTEGRATION_TEST.md` /
`DOCKER_INTEGRATION_TEST.md` (Noise gateway) and `docs/backend_setup.md` (local
Phoenix).

## Intent

Keep `main` green while coverage climbs: active suites run under coveralls with
a **non-regression floor**; broken or schema-drifted tests live as `*.disabled`
under `pending_*` until restored. Raise `backend/coveralls.json`
`minimum_coverage` toward **70%** as suites return.

## CI jobs

| Job | What it runs | Artifacts on failure / always |
|-----|--------------|-------------------------------|
| `backend` | `mix format --check-formatted`, `mix credo --strict`, `mix sobelow.apps`, `mix dialyzer`, DB create/migrate, `mix coveralls.json --umbrella` | `backend-coverage` (`excoveralls.json`, HTML) |
| `dart-packages` | `dart test` in `libmsgr_core` and `libmsgr_cli` | — |
| `flutter` | `flutter format`, `flutter test --coverage` (needs `dart-packages`) | `flutter-coverage` (`lcov.info`) |
| `integration` | `scripts/ci_integration_env.sh` → `pytest -m integration -v` against compose (`docker-compose.yml` + `docker-compose.ci.yml`) | `integration-logs` on failure |

Triggers: push to `main`, all pull requests. Backend job uses Postgres 15 service
and Mix env `test`.

### Toolchain note

CI pins **Elixir 1.19.1 / OTP 28.1.1** via `erlef/setup-beam`. Cursor Cloud /
some local setups may still use **1.16.2 / OTP 26** (see `Agents.md`) because
the committed `backend/.tool-versions` pin does not always compile cleanly
without semver git tags. Prefer matching CI when fixing or restoring suites.

## Coverage floor

Configured in `backend/coveralls.json`:

- `minimum_coverage`: **12** (floor today; target 70%)
- Skips `application.ex`, `release.ex`, `telemetry.ex`, `repo.ex`, tests, deps

Local:

```bash
cd backend
MIX_ENV=test mix do --app msgr ecto.create --quiet, --app msgr ecto.migrate --quiet
mix coveralls.html --umbrella   # or coveralls.json
```

If Prometheus is already bound (dev server on **9568**), set
`PROMETHEUS_ENABLED=false` or stop the server first — otherwise `mix test` /
coveralls can fail with `:eaddrinuse`.

## Pending / disabled suites

ExUnit only compiles `*_test.exs`. Files renamed to `*.exs.disabled` under
`pending_failures/` or `pending_noise/` are **not** run. Per-app READMEs explain
why (Elixir 1.19 pattern rules, removed in-process Noise, schema drift, etc.).

Approximate inventory (count `*.disabled`):

| Path | Role |
|------|------|
| `apps/msgr/test/pending_failures/` | Core domain / chat / bridges |
| `apps/msgr/test/pending_noise/` | Former in-process Noise transport |
| `apps/msgr_web/test/pending_failures/` | Controllers / channels |
| `apps/msgr_web/test/pending_noise/` | Web Noise handshake flows |
| `apps/auth_provider/test/pending_*` | OIDC / device / token |
| `apps/teams/test/pending_failures/` | Tenant / channel |
| `apps/family_space/`, `apps/slack_api/` | Smaller parked sets |

### Restoring a suite

1. Move `foo_test.exs.disabled` → `foo_test.exs` (out of `pending_*` into the
   normal `test/` tree, or keep path and only fix the extension if the folder
   convention still applies for your app).
2. Fix compile/runtime failures against current schemas and APIs.
3. Run the file alone: `cd backend && mix test apps/<app>/test/path/to/foo_test.exs`
4. Re-run coveralls; if the floor allows, bump `minimum_coverage` in a dedicated
   commit when a meaningful batch is green again.
5. Update the local `pending_*/README.md` if the folder empties or reasons change.

Do not re-enable Noise in-process suites without confirming the Rust gateway /
gRPC path they should assert against instead.

## Integration tests (pytest)

```bash
bash scripts/ci_integration_env.sh   # writes CI .env secrets
pytest -m integration -v --tb=short
```

`MSGR_INTEGRATION_TIMEOUT` (CI default `360`) bounds stack bring-up. On failure,
collect compose logs the same way CI does (`docker compose … logs`). Tear down
with volumes when finished so the next run starts clean.

E2EE wire verification (separate from pytest): see `docs/e2ee_spec.md` and
`scripts/run_e2ee_e2e.sh`.

## Common pitfalls

- **`mix setup` recursion** — umbrella `cmd --app … mix setup` can fail when
  `castle`/`n` derive version from `git describe` without semver tags. Prefer
  explicit `ecto.create` / `ecto.migrate` (CI does this).
- **Format / credo noise** — CI is strict; run `mix format` and
  `mix credo --strict` before push. `mix lint` runs format check + credo +
  sobelow.
- **Dialyzer PLT** — first run is slow; CI caches `backend/priv/plts`.
- **Rust gateway** — `cargo test` is **not** in this workflow yet
  (`CODEBASE_ANALYSIS` P1).
- **Personal vs team media** — ClamAV coverage lives under team media tests;
  see `docs/media_virus_scan.md`.
