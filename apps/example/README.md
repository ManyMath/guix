# guix-example

This is the smallest complete example in the repo.

It is a plain Flutter Linux app with pinned Guix files and a checked-in release
hash, so you can build it and see what a known-good result looks like.

## Build It Here

Run these commands from this directory:

```sh
dart run ../../packages/guix/bin/guix_dart.dart setup linux
dart run ../../packages/guix/bin/guix_dart.dart build linux
./tool/hash_linux_bundle.sh --check
```

Expected normalized Linux bundle hash:

```text
c8f2de178fa1c21d6bb88ce50d6b5925b4c0ebda8a8d6e939bdd450e18ce38dd
```

That value is stored in `expected-hashes/linux-x86_64.sha256`.
It only applies to this app and the pinned toolchain in this directory.

The first command fetches Flutter `3.24.5` into `.flutter-sdk/` if it is not
already present. The official Flutter 3.24.5 Linux x86_64 archive SHA-256 is
pinned in `guix.yaml`, so setup verifies that download. The aarch64 checksum
remains empty.

If you prefer shorter commands, the same flow is wrapped in `make guix-setup`,
`make guix-build`, and `make verify-linux`.

## Other Ways To Use The Package

### Run the CLI straight from a checkout
This is the path shown above. It is handy when you are working in a clone or
fork of this repository and do not want to install anything globally.

```sh
dart run ../../packages/guix/bin/guix_dart.dart setup linux
dart run ../../packages/guix/bin/guix_dart.dart build linux
./tool/hash_linux_bundle.sh --check
```

### Install `guix_dart` from `pub.dev`
If you prefer the published CLI, the same example works that way too:

```sh
dart pub global activate guix
guix_dart setup linux
guix_dart build linux
./tool/hash_linux_bundle.sh --check
```

Run those commands from this directory if you want to verify the checked-in
example, or from your own project root after you copy over the relevant files.

### Use the CLI in an existing project
If you already have a Flutter app and do not want to vendor this repository,
copy these files into your app:

- `guix.yaml`
- `guix/channels.scm`
- `guix/linux.scm`
- `tool/hash_linux_bundle.sh`

Then use the installed CLI:

```sh
dart pub global activate guix
guix_dart setup linux
guix_dart build linux
./tool/hash_linux_bundle.sh
```

After your first known-good build, replace
`expected-hashes/linux-x86_64.sha256` with a hash from your own app. Once you
change the app code, do not expect it to match the reference hash shown above.

### Add the repo as a git subtree and keep the CLI
This is the vendored setup described in the main repo README. The layout is a
little different from this example: in a host project, the full repo lives
under `guix/`.

From your host project root:

```sh
git subtree add --prefix=guix https://github.com/ManyMath/guix.git main --squash
bash guix/bootstrap.sh
dart pub global activate guix
make guix-build
```

If you use `Makefile.inc`, add this to your project `Makefile`:

```make
GUIX_FLUTTER_DIR ?= guix
include $(GUIX_FLUTTER_DIR)/Makefile.inc
```

If you later add a `guix.yaml`-driven config to that host project, use
`make guix-sync` to regenerate the `.env` files from it.

### Add the repo as a git subtree and use only shell scripts
There is also a shell-only path with no Dart dependency. In that mode the repo
uses `guix-flutter.conf`, `flutter_version.env`, and
`android_sdk_version.env` instead of `guix.yaml`.

From your host project root:

```sh
git subtree add --prefix=guix https://github.com/ManyMath/guix.git main --squash
bash guix/bootstrap.sh
$EDITOR flutter_version.env
$EDITOR android_sdk_version.env
make guix-setup
make guix-build
```

If you want the same hash check there, copy `tool/hash_linux_bundle.sh` into
your host project and commit an expected hash for that project's own first
known-good build.

### Eject standalone scripts from a config-driven project
If you start from this example, or any other `guix.yaml` project, and later
want standalone scripts, use `eject` once:

```sh
dart run ../../packages/guix/bin/guix_dart.dart eject
./scripts/fetch-flutter.sh
make -f Makefile.generated build-linux
./tool/hash_linux_bundle.sh
```

That writes self-contained scripts, `.env` files, and `Makefile.generated`,
after which you can stop depending on `guix_dart` for day-to-day builds.

## Reuse The Example

If you already have a Flutter app, start by copying:

- `guix.yaml`
- `guix/channels.scm`
- `guix/linux.scm`
- `tool/hash_linux_bundle.sh`

Then change `platforms.linux.build.command` and `platforms.linux.build.output`
to match your app.

If you would rather start from this repo and swap in your own app, replace:

- `lib/`
- `linux/`
- `pubspec.yaml`

Keep the Guix files and the hash script in place until your own build is stable.
