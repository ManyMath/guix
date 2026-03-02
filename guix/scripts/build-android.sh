#!/usr/bin/env bash
# Build the Flutter Android app inside a Guix shell.
# This is a non-interactive build: suitable for CI.
set -euo pipefail

# Resolve paths: scripts live at <root>/<guix-dir>/scripts/
GUIX_FLUTTER_DIR="$(basename "$(cd "$(dirname "$0")/.." && pwd)")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Load project config if present.
CONF="$PROJECT_ROOT/guix-flutter.conf"
[ -f "$CONF" ] && source "$CONF"

FLUTTER_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"
ANDROID_DIR="$PROJECT_ROOT/.android-sdk"

if [ ! -d "$FLUTTER_DIR" ]; then
    echo "Flutter SDK not found. Run scripts/fetch-flutter.sh first."
    exit 1
fi

if [ ! -d "$ANDROID_DIR/cmdline-tools" ]; then
    echo "Android SDK not found. Run scripts/fetch-android-sdk.sh first."
    exit 1
fi

GUIX_CMD=(guix)
if [ "${1:-}" = "--pinned" ]; then
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/channels.scm" --)
fi

echo "Building Flutter Android app in Guix shell..."

export FLUTTER_GUIX_SDK_DIR="$FLUTTER_DIR"
export FLUTTER_GUIX_PROJECT_ROOT="$PROJECT_ROOT"
export FLUTTER_GUIX_ANDROID_SDK="$ANDROID_DIR"

"${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/android.scm" \
    --preserve='^FLUTTER_GUIX_' \
    -- bash -c '
set -euo pipefail
export PATH="$FLUTTER_GUIX_SDK_DIR/bin:$PATH"
export FLUTTER_ROOT="$FLUTTER_GUIX_SDK_DIR"
export ANDROID_HOME="$FLUTTER_GUIX_ANDROID_SDK"
export ANDROID_SDK_ROOT="$FLUTTER_GUIX_ANDROID_SDK"
export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which java))))"
cd "$FLUTTER_GUIX_PROJECT_ROOT"

echo "--- flutter pub get ---"
flutter pub get

echo "--- flutter build apk ---"
flutter build apk --release

echo "Build complete. Output:"
ls -la build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || echo "APK not found"
'
