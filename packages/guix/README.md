# guix
A CLI tool for reproducible Dart and Flutter builds with [GNU Guix](https://guix.gnu.org/).

## Installation
```sh
dart pub global activate guix
```

## Quick start
```sh
# In your Flutter project root:
guix_dart init linux  # Create guix.yaml + guix/linux.scm.
guix_dart setup       # Fetch Flutter SDK.
guix_dart shell linux # Enter reproducible dev shell.
guix_dart build linux # Build (pinned, CI-safe).
```

## Commands
| Command | Description |
|---------|-------------|
| `init [linux] [android]` | Initialise config and manifests |
| `setup [platforms...]` | Fetch Flutter SDK and platform SDKs |
| `shell <platform>` | Enter an interactive Guix dev shell |
| `build <platform>` | Build inside a reproducible environment |
| `doctor` | Check prerequisites and configuration |
| `pin` | Update `guix/channels.scm` from current Guix |
| `clean` | Remove SDKs and build artifacts |
| `eject` | Generate standalone shell scripts |

Pass `--help` to any command for full usage.

## `guix.yaml` schema
```yaml
project:
  name: my_app

flutter:
  version: "3.24.5"
  channel: stable
  checksums:
    x86_64: ""      # SHA-256 of the downloaded tarball
    aarch64: ""

guix:
  channels: guix/channels.scm

platforms:
  linux:
    manifest: guix/linux.scm
    env:
      CC: clang
      CXX: clang++
    preserve:
      - DISPLAY
      - WAYLAND_DISPLAY
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle

  android:
    manifest: guix/android.scm
    build:
      command: flutter build apk --release
      output: build/app/outputs/flutter-apk/app-release.apk

profiles:
  staging:
    platform: linux
    command: flutter build linux --release --dart-define=FLAVOR=staging
    output: build/linux/staging/bundle
```

## Requirements
- [GNU Guix](https://guix.gnu.org/manual/en/html_node/Installation.html) installed on the host
- Dart SDK `>=3.5.0`

## Ejecting
If you no longer want to depend on this tool, `guix_dart eject` generates self-contained shell scripts and a `Makefile` that reproduce the same behaviour without any Dart tooling.
