# guix: Reproducible Flutter Builds with GNU Guix

Use [GNU Guix](https://guix.gnu.org/) to declare and pin every system
dependency a Flutter app needs, on a per-platform basis.

## How it works
asd
| Layer | What | Reproducibility mechanism |
|-------|------|---------------------------|
| System deps | clang, GTK, mesa, ... | `guix/linux.scm` manifest + `guix/channels.scm` pin |
| Flutter SDK | Dart + framework | `flutter_version.env` (version + SHA-256, per-arch) |
| Dart deps | pub packages | `pubspec.lock` (standard Flutter) |

Running `guix time-machine -C guix/channels.scm -- shell -m guix/linux.scm`
gives you a shell where every C library, every header, every tool is at the
**exact same version** as every other developer on the project, no matter
what Linux distro the host runs (x86_64 and arm64 supported).

## Prerequisites

1. [Install GNU Guix](https://guix.gnu.org/manual/en/html_node/Installation.html)
   as a package manager on your existing distro (Ubuntu 24.04, etc.).
   You do **not** need Guix System, just the daemon + CLI.
   You may need to `sudo apt install uidmap` first.

2. Make sure `guix` is on your `$PATH`.

## Quick start (Linux)

```bash
# One-command setup (pins channels + fetches Flutter SDK):
make setup

# Enter the reproducible dev shell:
make shell            # latest local Guix (fast)
make shell-pinned     # fully pinned (reproducible, slower first time)

# Inside the shell:
flutter doctor
flutter run -d linux
flutter build linux --release
```

Or without make:

```bash
./guix/pin-channels.sh
./scripts/fetch-flutter.sh
./scripts/shell-linux.sh --pinned
```

CI build (non-interactive, fully pinned):

```bash
make build
```

## Adding a new platform

1. Create `guix/<platform>.scm` with the platform's native dependencies.
2. Create `scripts/shell-<platform>.sh` and `scripts/build-<platform>.sh`.
3. Add make targets for the new platform.

## Updating

- **Guix packages**: run `guix pull` then `make pin`.
- **Flutter SDK**: edit `flutter_version.env`, run `make setup`.
- **Dart deps**: `flutter pub upgrade` then commit `pubspec.lock`.
