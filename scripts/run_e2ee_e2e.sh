#!/usr/bin/env bash
# Boot Phoenix (dev) with bot auth and run the Dart HTTP E2EE E2E suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${E2EE_E2E_BASE_URL:-http://127.0.0.1:4000}"
BOT_SECRET="${BOT_AUTH_SECRET:-dev-bot-secret-e2e}"
PORT="${PORT:-4000}"
export BOT_AUTH_SECRET="$BOT_SECRET"
export E2EE_E2E_BASE_URL="$BASE_URL"
export PHX_LISTEN_IP="${PHX_LISTEN_IP:-127.0.0.1}"
export PORT
export SWOOSH_LOCAL_ADAPTER="${SWOOSH_LOCAL_ADAPTER:-true}"
export MIX_ENV="${MIX_ENV:-dev}"
export PROMETHEUS_ENABLED="${PROMETHEUS_ENABLED:-false}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "==> Ensuring Postgres is up"
sudo service postgresql start >/dev/null 2>&1 || sudo pg_ctlcluster 16 main start >/dev/null 2>&1 || true

echo "==> Preparing dev database"
cd "$ROOT/backend"
mix ecto.create >/dev/null 2>&1 || true
mix ecto.migrate

echo "==> Starting Phoenix on $BASE_URL (BOT_AUTH_SECRET set)"
mix phx.server > /tmp/e2ee_e2e_phx.log 2>&1 &
SERVER_PID=$!

echo "==> Waiting for /health"
for i in $(seq 1 60); do
  if curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "Phoenix exited early; log:"
    tail -80 /tmp/e2ee_e2e_phx.log || true
    exit 1
  fi
  sleep 1
  if [[ "$i" -eq 60 ]]; then
    echo "Timed out waiting for health; log:"
    tail -80 /tmp/e2ee_e2e_phx.log || true
    exit 1
  fi
done

echo "==> Running Dart E2EE HTTP E2E"
cd "$ROOT/flutter_frontend/packages/libmsgr_core"
dart pub get >/dev/null
dart test test/e2ee/e2ee_http_e2e_test.dart

echo "==> E2EE HTTP E2E passed"
