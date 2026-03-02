#!/usr/bin/env bash
# Bootstrap guix-flutter-scripts in a host project.
# Run once after adding guix-flutter-scripts to your project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# When used as a subtree under a host project, PROJECT_ROOT is the parent.
# When used standalone, PROJECT_ROOT is SCRIPT_DIR itself.
if [ -f "$SCRIPT_DIR/../guix-flutter.conf" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/guix-flutter.conf" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
else
    # Assume we're being run from within the subtree in a host project.
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

echo "=== guix-flutter-scripts bootstrap ==="
echo "Scripts dir: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Check prerequisites.
if ! command -v guix &>/dev/null; then
    echo "ERROR: GNU Guix is not installed."
    echo "Install from: https://guix.gnu.org/manual/en/html_node/Installation.html"
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo "ERROR: git is not installed."
    exit 1
fi

echo "Prerequisites OK (guix $(guix --version 2>&1 | head -1 | awk '{print $NF}'), git $(git --version | awk '{print $NF}'))"
echo ""

# Copy template files if not present.
copy_template() {
    local src="$1" dst="$2" name="$3"
    if [ -f "$dst" ]; then
        echo "  $name already exists, skipping."
    else
        cp "$src" "$dst"
        echo "  Created $name: edit to match your project."
    fi
}

echo "Checking config files..."
copy_template "$SCRIPT_DIR/guix-flutter.conf.example" "$PROJECT_ROOT/guix-flutter.conf" "guix-flutter.conf"
copy_template "$SCRIPT_DIR/flutter_version.env.example" "$PROJECT_ROOT/flutter_version.env" "flutter_version.env"
copy_template "$SCRIPT_DIR/android_sdk_version.env.example" "$PROJECT_ROOT/android_sdk_version.env" "android_sdk_version.env"
echo ""

# Pin Guix channels.
echo "Pinning Guix channels..."
"$SCRIPT_DIR/pin-channels.sh"
echo ""

# Fetch Flutter SDK.
echo "Fetching Flutter SDK..."
"$SCRIPT_DIR/scripts/fetch-flutter.sh"
echo ""

echo "=== Bootstrap complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit flutter_version.env to pin your Flutter version"
echo "  2. Run 'make guix-shell' to enter the dev shell"
echo "  3. Run 'make guix-build' for a reproducible build"
