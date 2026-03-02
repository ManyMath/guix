# Makefile.inc: include this from your project's Makefile.
# Usage:
#   GUIX_FLUTTER_DIR ?= guix
#   include $(GUIX_FLUTTER_DIR)/Makefile.inc

GUIX_FLUTTER_DIR ?= guix
GUIX_FLUTTER_SCRIPTS := $(GUIX_FLUTTER_DIR)/scripts
GUIX_FLUTTER_MANIFESTS := $(GUIX_FLUTTER_DIR)/manifests

.PHONY: guix-setup guix-shell guix-shell-pinned guix-build guix-build-fast \
        guix-setup-android guix-shell-android guix-shell-android-pinned \
        guix-build-android guix-build-android-fast \
        guix-pin guix-clean

guix-setup:
	$(GUIX_FLUTTER_DIR)/pin-channels.sh
	$(GUIX_FLUTTER_SCRIPTS)/fetch-flutter.sh

guix-shell:
	$(GUIX_FLUTTER_SCRIPTS)/shell-linux.sh

guix-shell-pinned:
	$(GUIX_FLUTTER_SCRIPTS)/shell-linux.sh --pinned

guix-build:
	$(GUIX_FLUTTER_SCRIPTS)/build-linux.sh --pinned

guix-build-fast:
	$(GUIX_FLUTTER_SCRIPTS)/build-linux.sh

guix-setup-android: guix-setup
	guix shell -m $(GUIX_FLUTTER_MANIFESTS)/android.scm -- $(GUIX_FLUTTER_SCRIPTS)/fetch-android-sdk.sh

guix-shell-android:
	$(GUIX_FLUTTER_SCRIPTS)/shell-android.sh

guix-shell-android-pinned:
	$(GUIX_FLUTTER_SCRIPTS)/shell-android.sh --pinned

guix-build-android:
	$(GUIX_FLUTTER_SCRIPTS)/build-android.sh --pinned

guix-build-android-fast:
	$(GUIX_FLUTTER_SCRIPTS)/build-android.sh

guix-pin:
	$(GUIX_FLUTTER_DIR)/pin-channels.sh

guix-clean:
	rm -rf .flutter-sdk .android-sdk build
