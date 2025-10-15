#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter_frontend"

HOST="${MSGR_BACKEND_HOST:-}"
if [[ -z "$HOST" ]]; then
  if [[ $# -gt 0 ]]; then
    HOST="$1"
    shift
  else
    HOST="auth.7f000001.nip.io"
  fi
fi

pushd "$FLUTTER_DIR" >/dev/null
flutter pub get
exec flutter run --dart-define=MSGR_BACKEND_HOST="$HOST" "$@"
