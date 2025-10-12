#!/usr/bin/env bash
#
# Install Frida CLI tools and download the matching frida-server binary.
# Works on macOS/Linux. Windows users can run the PowerShell variant.
#
# Usage:
#   ./setup_frida_env.sh [--arch android-arm64|android-x86_64] [--output ./reverse/frida/bin]
#
set -euo pipefail

OUTPUT_DIR="$(pwd)/reverse/frida/bin"
ANDROID_ARCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      shift
      ANDROID_ARCH="$1"
      ;;
    --output)
      shift
      OUTPUT_DIR="$1"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift || true
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required. Install it first." >&2
  exit 1
fi

echo "[Frida] Installing Python packages (frida-tools, frida)"
python3 -m pip install --user --upgrade frida-tools frida

FRIDA_VERSION="$(python3 - <<'PY'
import frida, sys
sys.stdout.write(frida.__version__)
PY
)"

if [[ -z "$FRIDA_VERSION" ]]; then
  echo "Failed to determine Frida version." >&2
  exit 1
fi

if [[ -z "$ANDROID_ARCH" ]]; then
  echo "[Frida] Detecting device ABI via adb (fallback to android-arm64)"
  if command -v adb >/dev/null 2>&1; then
    DEVICE_ABI="$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
    if [[ "$DEVICE_ABI" == *"x86_64"* ]]; then
      ANDROID_ARCH="android-x86_64"
    elif [[ "$DEVICE_ABI" == *"x86"* ]]; then
      ANDROID_ARCH="android-x86"
    else
      ANDROID_ARCH="android-arm64"
    fi
  else
    ANDROID_ARCH="android-arm64"
  fi
fi

echo "[Frida] Targeting frida-server for $ANDROID_ARCH"
SERVER_NAME="frida-server-${FRIDA_VERSION}-${ANDROID_ARCH}"
DOWNLOAD_URL="https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/${SERVER_NAME}.xz"
DOWNLOAD_PATH="$(mktemp)"

echo "[Frida] Downloading ${DOWNLOAD_URL}"
curl -L --fail "$DOWNLOAD_URL" -o "$DOWNLOAD_PATH"

TARGET_PATH="$OUTPUT_DIR/$SERVER_NAME"

echo "[Frida] Decompressing to $TARGET_PATH"
python3 - "$DOWNLOAD_PATH" "$TARGET_PATH" <<'PY'
import lzma
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
data = lzma.open(src, "rb").read()
dst.write_bytes(data)
PY

chmod +x "$TARGET_PATH"
rm -f "$DOWNLOAD_PATH"

cat <<EOF

[Frida] Setup complete!
- python3 -m pip install --user frida-tools frida
- frida-server stored at: $TARGET_PATH

Deploy to emulator/device:
  adb push "$TARGET_PATH" /data/local/tmp/frida-server
  adb shell "chmod 755 /data/local/tmp/frida-server"
  adb shell "/data/local/tmp/frida-server"

EOF
