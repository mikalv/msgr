#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NOISE_TRANSPORT_ENABLED="${NOISE_TRANSPORT_ENABLED:-true}"

exec docker compose -f "$ROOT_DIR/docker-compose.yml" up "$@"
