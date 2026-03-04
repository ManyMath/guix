# Makefile.inc: include this from your project's Makefile.
# Usage:
#   GUIX_FLUTTER_DIR ?= guix
#   include $(GUIX_FLUTTER_DIR)/Makefile.inc

GUIX_FLUTTER_DIR ?= guix
GUIX_FLUTTER_SCRIPTS := $(GUIX_FLUTTER_DIR)/scripts
GUIX_FLUTTER_MANIFESTS := $(GUIX_FLUTTER_DIR)/manifests

# Detect the guix_dart CLI; targets delegate to it when available.
GUIX_DART_BIN := $(shell command -v guix_dart 2>/dev/null)

.PHONY: guix-setup guix-shell guix-shell-pinned guix-build guix-build-fast \
        guix-setup-android guix-shell-android guix-shell-android-pinned \
        guix-build-android guix-build-android-fast \
        guix-sync guix-pin guix-clean

guix-setup:
ifdef GUIX_DART_BIN
	guix_dart setup && guix_dart sync
else
	$(GUIX_FLUTTER_DIR)/pin-channels.sh
	$(GUIX_FLUTTER_SCRIPTS)/fetch-flutter.sh
endif

guix-shell:
ifdef GUIX_DART_BIN
	guix_dart shell linux
else
	$(GUIX_FLUTTER_SCRIPTS)/shell-linux.sh
endif

guix-shell-pinned:
ifdef GUIX_DART_BIN
	guix_dart shell linux --pinned
else
	$(GUIX_FLUTTER_SCRIPTS)/shell-linux.sh --pinned
endif

guix-build:
ifdef GUIX_DART_BIN
	guix_dart build linux
else
	$(GUIX_FLUTTER_SCRIPTS)/build-linux.sh --pinned
endif

guix-build-fast:
ifdef GUIX_DART_BIN
	guix_dart build linux --fast
else
	$(GUIX_FLUTTER_SCRIPTS)/build-linux.sh
endif

guix-setup-android:
ifdef GUIX_DART_BIN
	guix_dart setup android && guix_dart sync
else
	$(MAKE) guix-setup
	guix shell -m $(GUIX_FLUTTER_MANIFESTS)/android.scm -- $(GUIX_FLUTTER_SCRIPTS)/fetch-android-sdk.sh
endif

guix-shell-android:
ifdef GUIX_DART_BIN
	guix_dart shell android
else
	$(GUIX_FLUTTER_SCRIPTS)/shell-android.sh
endif

guix-shell-android-pinned:
ifdef GUIX_DART_BIN
	guix_dart shell android --pinned
else
	$(GUIX_FLUTTER_SCRIPTS)/shell-android.sh --pinned
endif

guix-build-android:
ifdef GUIX_DART_BIN
	guix_dart build android
else
	$(GUIX_FLUTTER_SCRIPTS)/build-android.sh --pinned
endif

guix-build-android-fast:
ifdef GUIX_DART_BIN
	guix_dart build android --fast
else
	$(GUIX_FLUTTER_SCRIPTS)/build-android.sh
endif

# Re-generate .env files from guix.yaml (requires guix_dart).
guix-sync:
ifdef GUIX_DART_BIN
	guix_dart sync
else
	@echo "guix_dart not found. Install with: dart pub global activate guix"
	@echo "Then run: guix_dart sync"
	@echo "Or edit flutter_version.env and android_sdk_version.env manually."
endif

guix-pin:
	$(GUIX_FLUTTER_DIR)/pin-channels.sh

guix-clean:
	rm -rf .flutter-sdk .android-sdk build
