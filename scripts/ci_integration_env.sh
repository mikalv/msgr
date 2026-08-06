#!/usr/bin/env bash
# Generate a disposable .env for CI / local docker-compose integration runs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT/.env}"

if [[ -f "$ENV_FILE" ]]; then
  echo "Using existing $ENV_FILE"
  exit 0
fi

rand_b64() {
  openssl rand -base64 "$1" | tr -d '\n'
}

cat >"$ENV_FILE" <<EOF
SECRET_KEY_BASE=$(rand_b64 64)
SERVER_STATIC_KEY=$(rand_b64 32)
POSTGRES_PASSWORD=$(rand_b64 24)
OTP_HMAC_SECRET=$(rand_b64 32)
GF_SECURITY_ADMIN_PASSWORD=$(rand_b64 16)
ZO_ROOT_USER_PASSWORD=$(rand_b64 16)
POSTGRES_USERNAME=postgres
POSTGRES_DB=msgr_dev
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
CLAMAV_ENABLED=false
MSGR_WEB_LEGACY_ACTOR_HEADERS=true
NOISE_TRANSPORT_ENABLED=false
MSGR_TLS_ENABLED=false
EOF

echo "Wrote $ENV_FILE"
