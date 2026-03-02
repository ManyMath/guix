# Unified entry point for Guix-based Flutter development.
# All targets wrap the scripts/ directory.

.PHONY: setup shell shell-pinned build build-fast \
        setup-android shell-android shell-android-pinned build-android build-android-fast \
        pin clean

# Fetch Flutter SDK + pin Guix channels (first-time setup).
setup:
	./guix/pin-channels.sh
	./scripts/fetch-flutter.sh

# Interactive dev shell (uses latest local Guix).
shell:
	./scripts/shell-linux.sh

# Interactive dev shell (fully pinned — reproducible).
shell-pinned:
	./scripts/shell-linux.sh --pinned

# CI-friendly build (fully pinned).
build:
	./scripts/build-linux.sh --pinned

# Build with latest local Guix (faster, less reproducible).
build-fast:
	./scripts/build-linux.sh

# --- Android targets ---

# Fetch Android SDK components (requires Guix shell with JDK).
setup-android: setup
	guix shell -m guix/android.scm -- ./scripts/fetch-android-sdk.sh

# Interactive Android dev shell (uses latest local Guix).
shell-android:
	./scripts/shell-android.sh

# Interactive Android dev shell (fully pinned — reproducible).
shell-android-pinned:
	./scripts/shell-android.sh --pinned

# CI-friendly Android build (fully pinned).
build-android:
	./scripts/build-android.sh --pinned

# Android build with latest local Guix (faster, less reproducible).
build-android-fast:
	./scripts/build-android.sh

# --- Utility targets ---

# Re-pin Guix channels to current versions.
pin:
	./guix/pin-channels.sh

# Remove fetched SDKs and build artifacts.
clean:
	rm -rf .flutter-sdk .android-sdk build
