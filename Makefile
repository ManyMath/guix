# Example host project Makefile.
# The guix-flutter-scripts targets are available via include.

GUIX_FLUTTER_DIR ?= guix
include $(GUIX_FLUTTER_DIR)/Makefile.inc

# --- Host project targets ---

.PHONY: test run

test:
	@echo "Running host project tests..."
	flutter test

run:
	@echo "Running host project..."
	flutter run
