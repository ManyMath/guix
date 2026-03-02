#!/usr/bin/env bash
# Download and configure a pinned Android SDK using Google's cmdline-tools.
# The SDK is stored in .android-sdk/ (git-ignored).
# Requires `java` on PATH (run inside `guix shell -m guix/android.scm`).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_ROOT/android_sdk_version.env"

SDK_DIR="$PROJECT_ROOT/.android-sdk"
SDKMANAGER="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"

# Check for java: needed by sdkmanager.
if ! command -v java &>/dev/null; then
    echo "ERROR: java not found on PATH."
    echo "Run inside:  guix shell -m guix/android.scm"
    exit 1
fi

# Ensure TLS certificates are available (Guix pure shell doesn't set these).
if [ -z "${SSL_CERT_DIR:-}" ] && [ -z "${SSL_CERT_FILE:-}" ]; then
    for d in "$GUIX_ENVIRONMENT" "$GUIX_PROFILE" /run/current-system/profile; do
        cert="${d:-}/etc/ssl/certs"
        if [ -d "$cert" ]; then
            export SSL_CERT_DIR="$cert"
            break
        fi
    done
fi

# Skip if SDK components already present.
if [ -x "$SDKMANAGER" ] && \
   [ -d "$SDK_DIR/platforms/$ANDROID_PLATFORM_VERSION" ] && \
   [ -d "$SDK_DIR/build-tools/$ANDROID_BUILD_TOOLS_VERSION" ] && \
   [ -d "$SDK_DIR/ndk/$ANDROID_NDK_VERSION" ]; then
    echo "Android SDK already configured in $SDK_DIR"
    exit 0
fi

ARCHIVE="commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"
URL="https://dl.google.com/android/repository/$ARCHIVE"

echo "Downloading Android cmdline-tools (build $ANDROID_CMDLINE_TOOLS_BUILD)..."
mkdir -p "$SDK_DIR"
cd "$SDK_DIR"

if ! curl -fLO "$URL"; then
    echo "ERROR: Failed to download $URL"
    rm -f "$ARCHIVE"
    exit 1
fi

# Verify checksum.
if [ -n "${ANDROID_CMDLINE_TOOLS_SHA256:-}" ]; then
    echo "Verifying checksum..."
    echo "$ANDROID_CMDLINE_TOOLS_SHA256  $ARCHIVE" | sha256sum -c -
else
    COMPUTED="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
    echo "WARNING: No SHA-256 hash set in android_sdk_version.env."
    echo "Computed hash: $COMPUTED"
    echo "Add to android_sdk_version.env:  ANDROID_CMDLINE_TOOLS_SHA256=\"$COMPUTED\""
fi

echo "Extracting cmdline-tools..."
rm -rf cmdline-tools
unzip -q "$ARCHIVE"
# Google's archive extracts to cmdline-tools/: sdkmanager expects
# cmdline-tools/latest/, so move it into place.
mkdir -p cmdline-tools/latest
mv cmdline-tools/bin cmdline-tools/lib cmdline-tools/latest/ 2>/dev/null || true
# Clean up any leftover files at the top level.
rm -f cmdline-tools/NOTICE.txt cmdline-tools/source.properties 2>/dev/null || true
rm -f "$ARCHIVE"

# Pre-create license files for non-interactive acceptance.
echo "Accepting Android SDK licenses..."
mkdir -p "$SDK_DIR/licenses"
echo -e "\n24333f8a63b6825ea9c5514f83c2829b004d1fee" \
    > "$SDK_DIR/licenses/android-sdk-license"
echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" \
    > "$SDK_DIR/licenses/android-sdk-preview-license"
echo -e "\nd975f751698a77e662f1cd748a3e6214bff89f2f" \
    > "$SDK_DIR/licenses/android-sdk-arm-dbt-license"
echo -e "\ne9acab5b5fbb560a72797e892a6e86da757adb8a" \
    > "$SDK_DIR/licenses/android-ndk-license"

echo "Installing SDK components via sdkmanager..."
"$SDKMANAGER" --sdk_root="$SDK_DIR" \
    "platform-tools" \
    "platforms;$ANDROID_PLATFORM_VERSION" \
    "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
    "ndk;$ANDROID_NDK_VERSION"

echo ""
echo "Android SDK ready at $SDK_DIR"
echo "Components installed:"
"$SDKMANAGER" --sdk_root="$SDK_DIR" --list_installed
