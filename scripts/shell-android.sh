#!/usr/bin/env bash
# Enter a reproducible Guix development shell for Android Flutter development.
#
# Usage:
#   ./scripts/shell-android.sh              # uses latest local Guix
#   ./scripts/shell-android.sh --pinned     # uses pinned channels (fully reproducible)
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"
ANDROID_DIR="$PROJECT_ROOT/.android-sdk"

if [ ! -d "$FLUTTER_DIR" ]; then
    echo "Flutter SDK not found. Run scripts/fetch-flutter.sh first."
    exit 1
fi

if [ ! -d "$ANDROID_DIR/cmdline-tools" ]; then
    echo "Android SDK not found. Run scripts/fetch-android-sdk.sh first (inside a Guix shell)."
    exit 1
fi

# Build the guix shell command.
GUIX_CMD=(guix)

if [ "${1:-}" = "--pinned" ]; then
    echo "Using pinned channels from guix/channels.scm"
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/guix/channels.scm" --)
fi

echo "Entering Guix shell with Android Flutter dependencies..."
echo "Flutter SDK: $FLUTTER_DIR"
echo "Android SDK: $ANDROID_DIR"

exec "${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/guix/android.scm" \
    -- bash --init-file <(cat <<INITEOF
export PATH="$FLUTTER_DIR/bin:\$PATH"
export FLUTTER_ROOT="$FLUTTER_DIR"
export ANDROID_HOME="$ANDROID_DIR"
export ANDROID_SDK_ROOT="$ANDROID_DIR"
export JAVA_HOME="\$(dirname \$(dirname \$(readlink -f \$(which java))))"
echo "Ready. Flutter, Android SDK, and JDK 17 provided by Guix."
echo "Try: flutter doctor"
INITEOF
)
