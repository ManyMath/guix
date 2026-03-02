#!/usr/bin/env bash
# Enter a reproducible Guix development shell for Linux Flutter development.
#
# Usage:
#   ./scripts/shell-linux.sh              # uses latest local Guix
#   ./scripts/shell-linux.sh --pinned     # uses pinned channels (fully reproducible)
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

# Build the guix shell command.
GUIX_CMD=(guix)

if [ "${1:-}" = "--pinned" ]; then
    echo "Using pinned channels from $GUIX_FLUTTER_DIR/manifests/channels.scm"
    GUIX_CMD=(guix time-machine -C "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/channels.scm" --)
fi

echo "Entering Guix shell with Linux Flutter dependencies..."
echo "Flutter SDK: $SDK_DIR"

exec "${GUIX_CMD[@]}" shell \
    -m "$PROJECT_ROOT/$GUIX_FLUTTER_DIR/manifests/linux.scm" \
    --preserve='^DISPLAY$' \
    --preserve='^WAYLAND_DISPLAY$' \
    --preserve='^XAUTHORITY$' \
    --preserve='^XDG_' \
    --preserve='^DBUS_' \
    -- bash --init-file <(cat <<INITEOF
export PATH="$SDK_DIR/bin:\$PATH"
export FLUTTER_ROOT="$SDK_DIR"
export CC=clang
export CXX=clang++
echo "Ready. Flutter and all Linux deps provided by Guix."
echo "Try: flutter doctor"
INITEOF
)
