#!/usr/bin/env bash
# Build the Flutter Linux app inside a Guix shell.
# This is a non-interactive build: suitable for CI.
set -euo pipefail

# Resolve paths: scripts live at <root>/<guix-dir>/scripts/
GUIX_FLUTTER_DIR="$(basename "$(cd "$(dirname "$0")/.." && pwd)")"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Load project config if present.
CONF="$PROJECT_ROOT/guix-flutter.conf"
[ -f "$CONF" ] && source "$CONF"

SDK_DIR="$PROJECT_ROOT/.flutter-sdk/flutter"

if [ ! -d "$SDK_DIR" ]; then
    echo "Flutter SDK not found. Run scripts/fetch-flutter.sh first."
    exit 1
fi

GUIX_CMD=(guix)
if [ "${1:-}" = "--pinned" ]; then
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/channels.scm" --)
fi

echo "Building Flutter Linux app in Guix shell..."

export FLUTTER_GUIX_SDK_DIR="$SDK_DIR"
export FLUTTER_GUIX_PROJECT_ROOT="$PROJECT_ROOT"

"${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/linux.scm" \
    --preserve='^FLUTTER_GUIX_' \
    -- bash -c '
set -euo pipefail
export PATH="$FLUTTER_GUIX_SDK_DIR/bin:$PATH"
export FLUTTER_ROOT="$FLUTTER_GUIX_SDK_DIR"
export CC=clang
export CXX=clang++
cd "$FLUTTER_GUIX_PROJECT_ROOT"

echo "--- flutter pub get ---"
flutter pub get

echo "--- flutter build linux ---"
flutter build linux --release

echo "Build complete. Output at:"
find build/linux -path "*/release/bundle" -type d -exec ls -la {} + 2>/dev/null
'
