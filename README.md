# guix
Reproducible Flutter builds using GNU Guix.

## Supported targets
| Target | Host OS | Status |
|--------|---------|--------|
| Linux desktop | Linux | Working |
| Android APK | Linux | Working |
| Web | Linux | Planned |

## Prerequisites
- [GNU Guix](https://guix.gnu.org/) (as a package manager on any Linux distro, or Guix System)
- Git
- An existing Flutter project

## Getting Started
guix-flutter-scripts works three ways:

### Option 1: pub.dev CLI only
No git subtree required.  Install once and use `guix_dart` commands directly:
```sh
dart pub global activate guix
guix_dart init linux android
guix_dart setup
guix_dart shell linux
guix_dart build android
```

Configuration lives in `guix.yaml`. Use `guix_dart sync` any time you edit the
YAML to regenerate the `.env` files that the standalone scripts read.

### Option 2: git subtree + CLI (recommended for teams)
Add the scripts via git subtree for version-controlled scripts, and let `guix_dart` handle setup and sync. `Makefile.inc` automatically delegates to `guix_dart` when it is on `PATH`:
```sh
# Add subtree once
git subtree add --prefix=guix https://github.com/ManyMath/guix.git main --squash

# Bootstrap (copies config templates, pins channels, fetches Flutter)
bash guix/bootstrap.sh

# Install CLI (optional but recommended)
dart pub global activate guix
guix_dart init --from-existing # Import existing .env into guix.yaml

# Daily use: Makefile delegates to guix_dart when available
make guix-shell
make guix-build-android

# Keep .env files in sync after editing guix.yaml
make guix-sync # Calls guix_dart sync
```

### Option 3: git subtree only (no Dart required)
Pure shell workflow.  No Dart or pub needed on CI or developer machines.

Edit `.env` files directly; `Makefile.inc` calls the scripts without delegation:
```sh
# Add subtree
git subtree add --prefix=guix \
    https://github.com/ManyMath/guix.git main --squash

# Bootstrap
bash guix/bootstrap.sh

# Edit config files directly
$EDITOR flutter_version.env
$EDITOR android_sdk_version.env

# Use Make targets
make guix-setup
make guix-shell
make guix-build-android
```

## Updating
```sh
git subtree pull --prefix=guix \
    https://github.com/ManyMath/guix.git main --squash
```

# Is it any good?
Yes.
