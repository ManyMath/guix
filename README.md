# poc-host-app

Proof-of-concept demonstrating how a Flutter project consumes
[guix-flutter-scripts](guix/README.md).

## Setup

```sh
make guix-setup
```

## Develop

```sh
make guix-shell
```

## Build

```sh
make guix-build
```

## How this was set up

```sh
flutter create poc_host_app
cd poc_host_app
git subtree add --prefix=guix <guix-flutter-scripts-url> main --squash
cat 'GUIX_FLUTTER_DIR ?= guix\ninclude $(GUIX_FLUTTER_DIR)/Makefile.inc' > Makefile
./guix/bootstrap.sh
```
