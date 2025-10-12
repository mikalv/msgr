#!/usr/bin/env bash
#
# Bootstrap a local Android SDK + emulator stack for reverse-engineering.
# Works on macOS and Linux. Windows users can run the PowerShell variant.
#
# Usage:
#   ./setup_android_sdk.sh [install_dir]
#   ANDROID_SDK_ROOT=/custom/path ./setup_android_sdk.sh
#
# The script installs:
#   - Android command line tools
#   - platform-tools (adb/fastboot)
#   - emulator binaries
#   - Android 13 (API 33) platform + Google APIs system image (x86_64)
#
# After completion you can create an emulator with:
#   $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager create avd \
#     --name Pixel_6_API_33 \
#     --package "system-images;android-33;google_apis;x86_64" \
#     --device "pixel_6"
#
set -euo pipefail

SDK_REVISION="9477386"
PACKAGES=(
  "platform-tools"
  "emulator"
  "platforms;android-33"
  "build-tools;33.0.2"
  "system-images;android-33;google_apis;x86_64"
)

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac";;
  Linux*) PLATFORM="linux";;
  *) echo "Unsupported host OS: $OS" >&2; exit 1;;
esac

INSTALL_ROOT="${1:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
mkdir -p "$INSTALL_ROOT"
INSTALL_ROOT="$(cd "$INSTALL_ROOT" && pwd)"

echo "[Setup] Installing Android SDK into: $INSTALL_ROOT"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

ZIP_URL="https://dl.google.com/android/repository/commandlinetools-${PLATFORM}-${SDK_REVISION}_latest.zip"
ZIP_PATH="$TMP_DIR/cmdline-tools.zip"

echo "[Setup] Downloading command line tools ($ZIP_URL)"
curl -L --fail "$ZIP_URL" -o "$ZIP_PATH"

echo "[Setup] Extracting command line tools"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"
mkdir -p "$INSTALL_ROOT/cmdline-tools"
rm -rf "$INSTALL_ROOT/cmdline-tools/latest"
mv "$TMP_DIR/cmdline-tools" "$INSTALL_ROOT/cmdline-tools/latest"

SDKMANAGER="$INSTALL_ROOT/cmdline-tools/latest/bin/sdkmanager"

echo "[Setup] Accepting licenses"
yes | "$SDKMANAGER" --sdk_root="$INSTALL_ROOT" --licenses > /dev/null

echo "[Setup] Installing core packages"
"$SDKMANAGER" --sdk_root="$INSTALL_ROOT" "${PACKAGES[@]}"

cat <<EOF

[Setup] Android SDK installation complete!

Export the following in your shell profile:
  export ANDROID_SDK_ROOT="$INSTALL_ROOT"
  export ANDROID_HOME="$INSTALL_ROOT"
  export PATH="\$ANDROID_SDK_ROOT/platform-tools:\$ANDROID_SDK_ROOT/emulator:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$PATH"

To create a Pixel 6 emulator (Android 13):
  \$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/avdmanager create avd \
    --name Pixel_6_API_33 \\
    --package "system-images;android-33;google_apis;x86_64" \\
    --device "pixel_6"

Start the emulator:
  \$ANDROID_SDK_ROOT/emulator/emulator -avd Pixel_6_API_33 -writable-system -no-snapshot

EOF
