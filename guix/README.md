# guix-flutter-scripts

Reproducible Flutter builds using GNU Guix.

Provides shell scripts and Guix manifests that give any Flutter project a
reproducible, hermetic build environment. Guix manages system-level
dependencies (GTK, clang, JDK, etc.) while Flutter and the Android SDK are
fetched and verified separately.

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

## Quick start

### 1. Add to your project

```sh
git subtree add --prefix=guix \
    https://github.com/user/guix-flutter-scripts.git main --squash
```

### 2. Set up your Makefile

```makefile
GUIX_FLUTTER_DIR ?= guix
include $(GUIX_FLUTTER_DIR)/Makefile.inc
```

### 3. Bootstrap

```sh
make guix-setup
```

This copies config templates, pins Guix channels, and downloads the Flutter SDK.
Edit `flutter_version.env` to match your project's Flutter version.

### 4. Develop

```sh
make guix-shell          # interactive dev shell (latest Guix)
make guix-shell-pinned   # interactive dev shell (pinned, reproducible)
```

### 5. Build

```sh
make guix-build          # reproducible Linux build
make guix-build-fast     # faster build (latest Guix, less reproducible)
```

### Android

```sh
make guix-setup-android        # download Android SDK (after guix-setup)
make guix-shell-android        # interactive Android dev shell
make guix-build-android        # reproducible Android APK build
```

## Project layout

When added to a host project, the structure looks like:

```
my-flutter-app/
├── guix/                          # guix-flutter-scripts (this repo)
│   ├── scripts/                   # fetch, build, and shell scripts
│   ├── manifests/                 # Guix package manifests (.scm)
│   ├── Makefile.inc               # includable Makefile targets
│   ├── pin-channels.sh            # pin Guix channels
│   ├── bootstrap.sh               # one-command setup
│   ├── guix-flutter.conf.example  # config template
│   ├── flutter_version.env.example
│   └── android_sdk_version.env.example
├── guix-flutter.conf              # your project's config (from template)
├── flutter_version.env            # your Flutter version pin
├── android_sdk_version.env        # your Android SDK version pin
├── Makefile                       # your Makefile (includes guix/Makefile.inc)
└── ...app source...
```

## Configuration

### guix-flutter.conf

```bash
# Where guix-flutter-scripts lives relative to project root.
GUIX_FLUTTER_DIR="guix"
```

### flutter_version.env

```bash
FLUTTER_VERSION="3.24.5"
FLUTTER_CHANNEL="stable"
FLUTTER_SHA256_X64=""      # set after first download
FLUTTER_SHA256_ARM64=""
```

### android_sdk_version.env

```bash
ANDROID_CMDLINE_TOOLS_BUILD="14742923"
ANDROID_CMDLINE_TOOLS_SHA256=""
ANDROID_PLATFORM_VERSION="android-34"
ANDROID_BUILD_TOOLS_VERSION="34.0.0"
ANDROID_NDK_VERSION="23.1.7779620"
```

## Make targets

| Target | Description |
|--------|-------------|
| `guix-setup` | Pin Guix channels + fetch Flutter SDK |
| `guix-shell` | Interactive Linux dev shell |
| `guix-shell-pinned` | Interactive Linux dev shell (fully reproducible) |
| `guix-build` | CI-friendly Linux build (fully pinned) |
| `guix-build-fast` | Linux build with latest Guix |
| `guix-setup-android` | Fetch Android SDK components |
| `guix-shell-android` | Interactive Android dev shell |
| `guix-shell-android-pinned` | Interactive Android dev shell (fully reproducible) |
| `guix-build-android` | CI-friendly Android APK build (fully pinned) |
| `guix-build-android-fast` | Android build with latest Guix |
| `guix-pin` | Re-pin Guix channels to current versions |
| `guix-clean` | Remove fetched SDKs and build artifacts |

## Updating

```sh
git subtree pull --prefix=guix \
    https://github.com/user/guix-flutter-scripts.git main --squash
```

## How it works

1. **Guix manifests** (`manifests/*.scm`) declare system-level packages (GTK, clang, JDK, etc.)
2. **Channel pinning** (`manifests/channels.scm`) locks the exact Guix commit for reproducibility
3. **Fetch scripts** download and verify the Flutter SDK and Android SDK with SHA-256 checksums
4. **Shell scripts** enter a `guix shell` with all dependencies, passing through display variables for GUI apps
5. **Build scripts** run `flutter build` inside the Guix shell, optionally using `guix time-machine` for full reproducibility

## License

MIT
