# Research 3: Packaging Flutter and Android SDK as a Custom Guix Channel

## Executive Summary

Packaging the Flutter SDK and Android SDK as proper Guix packages in a custom channel is **technically feasible but represents a significant engineering and maintenance investment**. The Nix ecosystem has achieved this with ~2,000+ lines of Nix code across dozens of files, maintained by multiple contributors over several years. No one has done this for Guix: there are zero existing Flutter or Dart packages in Guix, and the Android packaging in Guix covers only individual tools (adb, fastboot), not the SDK itself.

**Recommendation**: Pursue a phased hybrid approach. Start with `guix shell --emulate-fhs` for Flutter (Phase 1), package Android SDK components individually (Phase 2), and only attempt full Flutter-as-a-Guix-package if the project gains enough contributors to sustain ongoing maintenance (Phase 3).

---

## 1. Feasibility: Flutter SDK as a Guix Package

### 1.1 Fixed-Output Derivation for the Tarball

Yes, the Flutter SDK tarball can be fetched as a standard Guix `(origin ...)`:

```scheme
(define-public flutter-sdk
  (package
    (name "flutter-sdk")
    (version "3.24.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://storage.googleapis.com/flutter_infra_release/"
                    "releases/stable/linux/flutter_linux_"
                    version "-stable.tar.xz"))
              (sha256
               (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system copy-build-system)
    (arguments
     '(#:install-plan '(("." "share/flutter-sdk/"))
       #:phases
       (modify-phases %standard-phases
         (add-before 'install 'patch-binaries
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Patch ELF binaries in bin/cache/dart-sdk/
             ;; Flutter ships pre-built Dart, engine artifacts as ELF binaries
             (let ((patchelf (string-append (assoc-ref inputs "patchelf")
                                           "/bin/patchelf"))
                   (libc (assoc-ref inputs "glibc")))
               ;; Would need to patch every ELF binary in the tree
               ;; This is the hard part: see section 1.4
               #t)))
         (add-after 'install 'wrap-flutter
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (wrap-program (string-append out "/share/flutter-sdk/bin/flutter")
                 `("PUB_CACHE" ":" suffix (,(string-append
                                              (or (getenv "HOME") "/tmp")
                                              "/.pub-cache")))
                 `("FLUTTER_ROOT" = (,(string-append out "/share/flutter-sdk"))))))))))
    (native-inputs (list patchelf))
    (inputs (list glibc gcc:lib zlib))
    (home-page "https://flutter.dev")
    (synopsis "Google's UI toolkit for multi-platform apps")
    (description "Flutter SDK for building natively compiled applications.")
    (license license:bsd-3)))
```

This skeleton compiles but is **far from functional**: the real challenges follow.

### 1.2 Mutable State Problem

Flutter expects to write to several locations within its own directory:

| Location | Purpose | Solution |
|----------|---------|----------|
| `bin/cache/` | Engine artifacts, Dart SDK snapshots | Pre-populate at build time, or separate package |
| `.pub-cache/` | Downloaded pub packages | Redirect via `PUB_CACHE` env var to `$HOME/.pub-cache` |
| `bin/cache/flutter_tools.snapshot` | Compiled CLI tool | Build at package time (like Nix does) |
| `.git/` | Version detection | Create fake deterministic git repo at build time |
| `packages/flutter_tools/.dart_tool/` | Dart tool state | Symlink to pre-built package config |

The `PUB_CACHE` redirect is straightforward. The `FLUTTER_ROOT` pointing to the Guix store (read-only) works only if **all** cache artifacts are pre-populated. This is what Nix does with `flutter precache` inside a fixed-output derivation.

### 1.3 Engine Artifacts (flutter precache)

Flutter downloads ~200MB of platform-specific engine artifacts per target platform (linux, android, web, ios, macos). Nix handles this by:

1. Building a minimal Flutter (no artifacts) first
2. Running `flutter precache --linux` (or `--android`, etc.) inside a fixed-output derivation with network access
3. Capturing the output with a known hash

In Guix, the equivalent would be a `computed-file` or custom derivation with `#:hash` for fixed-output. However, Guix's build sandbox is stricter than Nix's: fixed-output derivations do get network access, but the approach requires:

- Running `flutter precache` during the build, which requires a working Dart binary
- The Dart binary inside Flutter is a pre-built ELF that needs `patchelf` treatment
- Each platform's artifacts need a separate hash in the package definition

This is the **single hardest part** of the packaging effort.

### 1.4 ELF Binary Patching

The Flutter SDK tarball contains ~50+ pre-built ELF binaries (Dart VM, engine, tools). On NixOS, `autoPatchelfHook` automatically fixes all ELF binaries by rewriting their `RPATH` and interpreter. **Guix has no equivalent automation**: each binary must be patched manually in build phases:

```scheme
(for-each
  (lambda (binary)
    (invoke "patchelf" "--set-interpreter"
            (string-append glibc "/lib/ld-linux-x86-64.so.2")
            binary)
    (invoke "patchelf" "--set-rpath"
            (string-append glibc "/lib:" gcc-lib "/lib:" zlib "/lib")
            binary))
  (find-files "bin/cache" (lambda (f s) (elf-file? f))))
```

This is tedious but not impossible. The risk is that **every Flutter version may change which binaries exist and what libraries they link**.

### 1.5 Prior Art

- **No one maintains Flutter Guix packages.** Zero results across Guix channels, GitHub, and mailing lists.
- **One abandoned attempt** exists on the System Crafters forum: a user tried packaging Dart but gave up due to the complexity of `depot_tools` (Chromium's build system, which Dart requires to build from source).
- **Building Dart from source is effectively impossible** in Guix without first packaging Google's entire `depot_tools` + `gclient` toolchain. The binary distribution is the only practical path.

---

## 2. Feasibility: Android SDK as Guix Packages

### 2.1 Modular Packaging

The Android SDK is inherently modular and maps well to individual Guix packages:

| Component | Archive Size | Update Frequency | Packaging Difficulty |
|-----------|-------------|-------------------|---------------------|
| cmdline-tools | ~150MB | Quarterly | Easy (single ZIP) |
| platform-tools | ~15MB | Quarterly | Easy (single ZIP) |
| build-tools;34.0.0 | ~65MB | Per-API-level | Easy (single ZIP) |
| platforms;android-34 | ~70MB | Per-API-level | Easy (single ZIP) |
| NDK;23.1.7779620 | ~1.1GB | Yearly | Medium (many ELF binaries to patch) |

Each can be a separate Guix package with `copy-build-system`, extracting archives to the correct directory structure.

### 2.2 Bypassing sdkmanager

Yes, `sdkmanager` can be bypassed entirely. Both Nix and the current project's `fetch-android-sdk.sh` demonstrate this. The SDK is just a collection of archives extracted to conventional paths:

```
$ANDROID_SDK_ROOT/
  cmdline-tools/latest/
  platform-tools/
  platforms/android-34/
  build-tools/34.0.0/
  ndk/23.1.7779620/
  licenses/
```

A Guix `android-sdk-composition` function could symlink individual packages into this tree:

```scheme
(define* (compose-android-sdk #:key platform-version build-tools-version
                               ndk-version)
  (computed-file "android-sdk"
    #~(begin
        (use-modules (guix build utils))
        (mkdir-p #$output)
        (symlink #$(android-platform platform-version)
                 (string-append #$output "/platforms/" #$platform-version))
        (symlink #$(android-build-tools build-tools-version)
                 (string-append #$output "/build-tools/" #$build-tools-version))
        ;; ... etc
        )))
```

### 2.3 License Handling

Android SDK licenses require acceptance. Other distros handle this differently:

- **Nix**: Gating mechanism: build fails with license text unless `android_sdk.accept_license = true` in nixpkgs config or `NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1` env var. Pre-writes license hash files.
- **Debian/Ubuntu**: Packages Android SDK tools but requires `sdkmanager --licenses` post-install.
- **Guix approach**: Could gate on a Guix configuration option or write license files during composition. Since the user explicitly installs the package, acceptance is implied (similar to how Guix handles other non-free firmware via `nonguix`).

Note: A channel distributing Android SDK components would likely need to be a **separate non-free channel** (like `nonguix`), not part of the official Guix repository, since Google's SDK has proprietary license terms.

### 2.4 NDK Store Size Implications

The NDK is ~1.1GB compressed, ~3-4GB extracted. In the Guix store:
- Each version occupies ~3-4GB in `/gnu/store/`
- Without a substitute server, building from source means extracting + patching ELF binaries (10-20 min)
- With a substitute server, downloading ~1.1GB compressed
- **Garbage collection** is important: old NDK versions accumulate fast

For comparison, Guix users already deal with large store items (texlive: ~4GB, ungoogled-chromium: ~2GB). The NDK is large but not unprecedented.

---

## 3. Custom Channel Architecture

### 3.1 Minimal Channel Structure

```
flutter-guix-channel/
├── .guix-channel                    # Channel metadata
├── flutter/
│   └── packages/
│       ├── flutter.scm              # Flutter SDK package
│       ├── dart.scm                 # Dart SDK (binary) package
│       ├── flutter-engine.scm       # Engine artifacts per-platform
│       └── android.scm              # Android SDK composition
```

`.guix-channel`:
```scheme
(channel
 (version 0)
 (directory "flutter"))
```

Users add to their `channels.scm`:
```scheme
(cons* (channel
         (name 'flutter-guix)
         (url "https://github.com/user/flutter-guix-channel.git"))
       %default-channels)
```

### 3.2 Binary Substitutes

Custom channels do **not** get substitutes from `ci.guix.gnu.org`. Options:

1. **Run your own Cuirass + `guix publish`**: requires a build server (4+ cores, 16GB+ RAM, 500GB+ storage for Flutter+Android SDK store items). Estimated cost: ~$50-100/month for a dedicated server.
2. **Use a CI service** to build and cache (e.g., GitHub Actions with `guix pack` artifacts): hacky, not a real substitute server.
3. **Users build from source**: for `copy-build-system` packages that just extract tarballs, this is fast (minutes). The bottleneck is downloading the large archives, which happens regardless.

Since Flutter and Android SDK packages would use `copy-build-system` (extract pre-built tarball, patch ELFs), builds are fast. The main cost is download time, not CPU time. **A substitute server is nice-to-have, not essential.**

### 3.3 Channel Pins and Package Versions

Channel commits map 1:1 to package versions. If Flutter 3.24.5 is defined in channel commit `abc123`, pinning the channel to `abc123` pins Flutter to 3.24.5.

```scheme
;; channels.scm: pins both Guix and the Flutter channel
(list
  (channel
    (name 'guix)
    (url "https://git.savannah.gnu.org/git/guix.git")
    (commit "5b3e234af51940feda1c9180384151a303d9a00a"))
  (channel
    (name 'flutter-guix)
    (url "https://github.com/user/flutter-guix-channel.git")
    (commit "abc123...")))
```

Then: `guix time-machine -C channels.scm -- shell -m manifest.scm` gives a fully reproducible environment.

This is a **strict improvement** over the current approach where Flutter version is pinned in `flutter_version.env` but fetched by a shell script outside Guix's dependency tracking.

---

## 4. Lessons from Nix's Flutter/Android Packaging

### 4.1 Nix Flutter Architecture (pkgs/development/compilers/flutter/)

Nix's Flutter packaging spans ~2,000 lines across 8+ files:

| File | Purpose | Complexity |
|------|---------|------------|
| `default.nix` | Version enumeration, exports | Low |
| `flutter.nix` | Core SDK derivation, fake git, symlinks | Medium |
| `flutter-tools.nix` | Builds flutter_tools CLI as JIT snapshot | High |
| `wrapper.nix` | Wraps with platform artifacts, native deps | High |
| `sdk-symlink.nix` | Unifies everything via symlinkJoin | Medium |
| `artifacts/fetch-artifacts.nix` | Fixed-output derivation for engine artifacts | High |
| `artifacts/prepare-artifacts.nix` | autoPatchelf on fetched artifacts | Medium |
| `versions/*/data.json` | Per-version metadata with all hashes | Generated |

Key innovations:
- **Layered build**: Minimal Flutter (no artifacts) → fetch artifacts as FOD → patch artifacts → combine via symlinks → wrap with env vars
- **`data.json` captures everything**: Dart version, engine hash, pubspec.lock with 80+ dependency hashes, artifact hashes per platform per host
- **Fake `.git`**: Deterministic git repo with epoch-0 timestamps to satisfy Flutter's version detection
- **`FLUTTER_ALREADY_LOCKED=true`**: Prevents Flutter from trying to self-update or modify the store

### 4.2 Problems Nix Encountered

1. **Constant breakage on Flutter updates**: Flutter's internal structure changes across versions. Build phases that worked for 3.24 may break on 3.27.
2. **Massive `data.json` maintenance**: Each Flutter version needs ~200 lines of hash data (pub dependencies, artifact hashes). This is partially automated but still requires manual verification.
3. **Platform matrix explosion**: Flutter supports 5 target platforms × 2-3 host platforms = 10-15 artifact hash combinations per version.
4. **Mutable state whack-a-mole**: Flutter's tools discover new mutable state expectations with each release. The Nix package maintainers constantly patch new writable-directory issues.
5. **Dart build system complexity**: `buildDartApplication` is itself ~500 lines and handles pub dependency fetching, snapshot compilation, package_config generation.

### 4.3 Nix Android SDK Architecture

Nix's `androidenv` takes the "composition function" approach:

```nix
android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
  cmdline-tools-latest
  build-tools-34-0-0
  platform-tools
  platforms-android-34
  ndk-23-1-7779620
])
```

Under the hood:
- A `repo.json` (generated from Google's XML repository metadata) maps every component to its URL, hash, and license.
- Each component is individually fetched with `fetchurl`.
- A composition function symlinks them into the expected directory tree.
- License acceptance is a build-time gate.
- `autoPatchelfHook` patches all ELF binaries automatically.

The `android-nixpkgs` community channel updates `repo.json` **daily** via automation. This is the gold standard for maintenance.

### 4.4 Key Takeaway

The Nix ecosystem needed **years of work by multiple skilled contributors** to reach the current state. The Flutter packaging has gone through numerous iterations and still breaks regularly. The Android SDK packaging is more stable because it's fundamentally simpler (extract archives, patch ELFs, compose directory tree).

---

## 5. Hybrid Approaches

### 5.1 Option A: `guix shell --emulate-fhs` for Flutter (Recommended Near-Term)

Use Guix's FHS emulation to run the pre-built Flutter SDK in a container:

```bash
guix shell --container --emulate-fhs --network \
  --share=$HOME/.pub-cache=$HOME/.pub-cache \
  --share=$PWD=$PWD \
  bash coreutils git curl unzip xz \
  gcc-toolchain gcc:lib glibc zlib \
  pkg-config gtk+ glib pango cairo gdk-pixbuf harfbuzz \
  mesa libepoxy fontconfig freetype at-spi2-core \
  libx11 libxext libxrandr libxcursor libxfixes \
  libxkbcommon dbus nss-certs \
  -- bash -c '
    export FLUTTER_ROOT=$PWD/.flutter-sdk/flutter
    export PATH=$FLUTTER_ROOT/bin:$PATH
    export PUB_CACHE=$HOME/.pub-cache
    flutter "$@"
  ' flutter "$@"
```

**Pros**: No Guix packaging needed for Flutter. All system deps are Guix packages. Flutter's ELF binaries work because FHS emulation provides `/lib/ld-linux-x86-64.so.2`.
**Cons**: Still requires fetching Flutter externally. Not a pure Guix package.

### 5.2 Option B: Package Android SDK Components, Script-Fetch Flutter

Package individual Android SDK components as simple Guix packages (easy: they're just tarballs), compose them with a Guile function, but keep Flutter as a script-fetched external. This gives Guix reproducibility for the Android SDK while avoiding the hardest packaging challenge (Flutter).

### 5.3 Option C: Use Guix `(origin ...)` with Fixed Hashes but Don't Fully Package

Define packages that do nothing more than download and extract the tarballs with verified hashes. No ELF patching, no wrapping: just a Guix-tracked download. Then use `--emulate-fhs` to actually run the binaries.

```scheme
(define-public flutter-sdk-binary
  (package
    (name "flutter-sdk-binary")
    (version "3.24.5")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://storage.googleapis.com/..."
                                  "flutter_linux_" version "-stable.tar.xz"))
              (sha256 (base32 "..."))))
    (build-system copy-build-system)
    (arguments '(#:install-plan '(("." "share/flutter-sdk/"))))
    (synopsis "Flutter SDK (pre-built binary, requires FHS)")
    (description "Use with guix shell --emulate-fhs")
    (license license:bsd-3)
    (home-page "https://flutter.dev")))
```

**Pros**: Minimal packaging effort. Hash-verified. Guix tracks the download.
**Cons**: Requires FHS wrapper to use. Not a "real" package (can't just `flutter doctor` after install).

---

## 6. Maintenance Burden

### 6.1 Flutter Release Cadence

- **Stable releases**: ~monthly (12/year)
- **Each release changes**: Version string, tarball hash, Dart SDK version, engine artifact hashes, pub dependency versions
- **Estimated effort per update**: 1-2 hours if automated hash computation exists, 4-8 hours if anything breaks (common)
- **Annual cost**: ~50-100 hours of skilled Guix developer time

### 6.2 Android SDK Update Cadence

- **Platform versions**: ~1/year (Android 14, 15, ...)
- **Build tools**: ~2-3/year
- **NDK versions**: ~2/year
- **cmdline-tools**: ~4/year
- **Estimated effort per update**: 30 min per component (update hash + version)
- **Annual cost**: ~10-20 hours

### 6.3 Channel Maintenance

| Task | Frequency | Time per Occurrence |
|------|-----------|---------------------|
| Flutter version bump | Monthly | 1-2h (if no breakage) |
| Android component update | Quarterly | 30min per component |
| Fix breakage from Flutter internal changes | 2-4x/year | 4-8h each |
| CI/substitute server maintenance | Ongoing | 2-4h/month |
| **Total annual estimate** | | **~120-200 hours** |

### 6.4 Bus Factor

Currently: **1** (whoever creates the channel). The Nix Flutter package has 3-4 active contributors and still struggles with timely updates. A solo maintainer would fall behind within 2-3 months.

**Mitigation**: Automate hash updates with a bot (watch Flutter releases → compute hashes → submit PR). Nix's `android-nixpkgs` updates `repo.json` daily via automation.

### 6.5 Automation Potential

A GitHub Action could:
1. Watch `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`
2. On new stable release: download tarball, compute `guix hash`, update package definition
3. For Android: parse Google's repository XML, update hashes
4. Submit PR for human review

This reduces per-update effort from hours to minutes of review. But initial automation setup is ~20-40 hours.

---

## 7. Comparison Table

| Dimension | Current Approach (Scripts) | Full Guix Channel | Hybrid (FHS + Partial Packaging) |
|-----------|---------------------------|-------------------|----------------------------------|
| **Reproducibility** | Good: SHA-256 hashes, pinned versions, but Flutter/Android outside Guix's DAG | Excellent: everything in Guix store, full dependency tracking | Very Good: Android in Guix, Flutter hash-verified but external |
| **Setup complexity** | Low: `make setup` | Low after `guix pull`: `guix shell -m manifest.scm` | Medium: needs FHS wrapper script |
| **Maintenance burden** | Low: update .env files | Very High: ~120-200h/year, needs dedicated maintainer | Medium: ~30-50h/year |
| **Build from source** | N/A (pre-built) | N/A (pre-built tarballs via copy-build-system) | N/A (pre-built) |
| **Substitute server** | N/A | Nice-to-have (~$50-100/month) | Not needed |
| **User experience** | Good: familiar Makefile workflow | Best: pure `guix shell`, no scripts | Good: single wrapper command |
| **Initial engineering** | Done (~2 weeks) | Very High: ~200-400 hours | Medium: ~40-80 hours |
| **Portability** | Linux x86_64 + ARM64 | Same + potential macOS (hard) | Same |
| **Bus factor risk** | Low (scripts are simple) | High (complex Guix Scheme) | Medium |
| **Community reuse** | Medium (copy scripts) | High (just add channel) | Medium |
| **Offline builds** | No (scripts download) | Yes (after guix pull) | Partially |

---

## 8. Recommendation

### Do Not Pursue a Full Guix Channel Now

The full channel approach is the "right" solution architecturally, but the cost-benefit ratio is poor for a project at this stage:

- **~200-400 hours of initial engineering** to reach feature parity with current scripts
- **~120-200 hours/year** ongoing maintenance
- **Bus factor of 1** makes it fragile
- **No existing Guix Flutter/Dart ecosystem** to build on (Nix had years of Dart packaging infrastructure before Flutter)
- The current script-based approach provides **90% of the reproducibility benefit** at **10% of the cost**

### Recommended Phased Approach

#### Phase 1: FHS-Based Flutter Wrapper (2-4 weeks)

Replace `fetch-flutter.sh` + env var setup with a `guix shell --emulate-fhs` wrapper. Flutter SDK is still downloaded externally but runs inside a Guix-managed FHS container.

**Deliverables**:
- `guix/flutter-fhs.sh`: wrapper script for FHS-based Flutter execution
- Updated Makefile targets
- Documented approach

**Value**: Eliminates manual `LD_LIBRARY_PATH` / `PKG_CONFIG_PATH` management. All native dependencies come from Guix. Flutter's pre-built ELF binaries work without patching.

#### Phase 2: Android SDK as Guix Packages (4-8 weeks)

Package Android SDK components as simple Guix packages in a custom channel:

```scheme
;; android-platform-34, android-build-tools-34, android-ndk-23, etc.
;; Each is just: download tarball → extract → patchelf → install
```

**Deliverables**:
- Custom Guix channel with Android SDK packages
- `compose-android-sdk` function
- Updated `android.scm` manifest using channel packages

**Value**: Eliminates `fetch-android-sdk.sh` and `sdkmanager` dependency. Full Guix reproducibility for Android toolchain. Android components are simpler to package than Flutter.

#### Phase 3: Flutter as Guix Package (If/When Justified)

Only pursue if:
- The project has 2+ contributors willing to maintain the channel
- An automated hash-update bot is in place
- Guix gains a `buildDartApplication` infrastructure (or you build one)
- There's demand from other Guix Flutter users

**Estimated timeline**: 3-6 months of part-time work by an experienced Guix packager.

### Alternative: Contribute Upstream

Instead of maintaining a custom channel, consider contributing Android SDK composition packages to the official Guix repository (or the `nonguix` channel for non-free components). This distributes the maintenance burden across the Guix community. The official `(gnu packages android)` module already has `sdkmanager`: building on that foundation is more sustainable than a solo channel.

---

## Appendix A: Draft Package Definitions

### A.1 Dart SDK (Binary)

```scheme
(define-module (flutter packages dart)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system copy)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc))

(define-public dart-sdk
  (package
    (name "dart-sdk")
    (version "3.5.4")  ;; Dart version bundled with Flutter 3.24.5
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://storage.googleapis.com/dart-archive/channels/"
                    "stable/release/" version
                    "/sdk/dartsdk-linux-x64-release.zip"))
              (sha256
               (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system copy-build-system)
    (arguments
     `(#:install-plan '(("dart-sdk" "share/dart-sdk/"))
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'patch-elf-binaries
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out"))
                   (glibc (assoc-ref inputs "glibc"))
                   (gcc-lib (assoc-ref inputs "gcc:lib")))
               (define (patch-binary path)
                 (invoke "patchelf" "--set-interpreter"
                         (string-append glibc "/lib/ld-linux-x86-64.so.2")
                         path)
                 (invoke "patchelf" "--set-rpath"
                         (string-append glibc "/lib:" gcc-lib "/lib")
                         path))
               (for-each patch-binary
                         (find-files (string-append out "/share/dart-sdk/bin")
                                     ".*" #:directories? #f))
               #t)))
         (add-after 'patch-elf-binaries 'create-bin-symlinks
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (mkdir-p (string-append out "/bin"))
               (symlink (string-append out "/share/dart-sdk/bin/dart")
                        (string-append out "/bin/dart"))
               #t))))))
    (native-inputs (list patchelf unzip))
    (inputs (list glibc `(,gcc "lib")))
    (home-page "https://dart.dev")
    (synopsis "Dart programming language SDK (pre-built binary)")
    (description "The Dart SDK includes the Dart VM, dart2js compiler,
and core libraries.")
    (license license:bsd-3)))
```

### A.2 Android Platform Package

```scheme
(define-module (flutter packages android-sdk)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public android-platform-34
  (package
    (name "android-platform-34")
    (version "2")  ;; revision
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://dl.google.com/android/repository/"
                    "platform-34-ext7_r02.zip"))
              (sha256
               (base32 "0000000000000000000000000000000000000000000000000000"))))
    (build-system copy-build-system)
    (arguments
     '(#:install-plan '(("android-14" "share/android-sdk/platforms/android-34/"))))
    (native-inputs (list unzip))
    (home-page "https://developer.android.com")
    (synopsis "Android SDK Platform API 34")
    (description "Android platform libraries for API level 34 (Android 14).")
    ;; Note: Android SDK is under Apache-2.0 but Google's additional terms apply.
    ;; This package would belong in a non-free channel.
    (license license:asl2.0)))
```

### A.3 Android SDK Composition (Sketch)

```scheme
(define* (compose-android-sdk #:key
                              (platform android-platform-34)
                              (build-tools android-build-tools-34)
                              (platform-tools android-platform-tools)
                              (ndk android-ndk-23))
  "Return a package that composes Android SDK components into a unified tree."
  (package
    (name "android-sdk")
    (version "0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     `(#:builder
       (begin
         (use-modules (guix build utils))
         (let ((out (assoc-ref %outputs "out"))
               (platform (assoc-ref %build-inputs "platform"))
               (build-tools (assoc-ref %build-inputs "build-tools"))
               (platform-tools (assoc-ref %build-inputs "platform-tools"))
               (ndk (assoc-ref %build-inputs "ndk")))
           ;; Create SDK directory structure
           (mkdir-p (string-append out "/share/android-sdk"))
           ;; Symlink components
           (symlink (string-append platform "/share/android-sdk/platforms")
                    (string-append out "/share/android-sdk/platforms"))
           (symlink (string-append build-tools "/share/android-sdk/build-tools")
                    (string-append out "/share/android-sdk/build-tools"))
           (symlink (string-append platform-tools "/share/android-sdk/platform-tools")
                    (string-append out "/share/android-sdk/platform-tools"))
           (symlink (string-append ndk "/share/android-sdk/ndk")
                    (string-append out "/share/android-sdk/ndk"))
           ;; Write license acceptance files
           (mkdir-p (string-append out "/share/android-sdk/licenses"))
           (call-with-output-file
               (string-append out "/share/android-sdk/licenses/android-sdk-license")
             (lambda (port)
               (display "24333f8a63b6825ea9c5514f83c2829b004d1fee\n" port)))
           #t))))
    (inputs (list platform build-tools platform-tools ndk))
    (home-page "https://developer.android.com")
    (synopsis "Composed Android SDK from individual components")
    (description "A unified Android SDK directory composed from individual
Guix-packaged components.")
    (license license:asl2.0)))
```

---

## Appendix B: Nix Flutter data.json Structure (Annotated)

For reference, this is the structure Nix maintains per Flutter version:

```json
{
  "version": "3.29.3",
  "engineVersion": "ea33ef234f2ecac0f84d44a57175033ef77e2bfc",
  "dartVersion": "3.7.2",
  "dartHash": {
    "x86_64-linux": "sha256-AAAA...",
    "aarch64-linux": "sha256-BBBB...",
    "x86_64-darwin": "sha256-CCCC...",
    "aarch64-darwin": "sha256-DDDD..."
  },
  "artifactHashes": {
    "android": {
      "x86_64-linux": "sha256-...",
      "aarch64-linux": "sha256-..."
    },
    "ios": { "x86_64-darwin": "sha256-...", "aarch64-darwin": "sha256-..." },
    "web": { "x86_64-linux": "sha256-...", "aarch64-linux": "sha256-..." },
    "linux": { "x86_64-linux": "sha256-...", "aarch64-linux": "sha256-..." },
    "macos": { "x86_64-darwin": "sha256-...", "aarch64-darwin": "sha256-..." },
    "windows": {}
  },
  "pubspecLock": {
    "packages": {
      "async": { "version": "2.12.0", "sha256": "...", "source": "hosted", "url": "https://pub.dev" },
      "collection": { "version": "1.19.1", "sha256": "...", "source": "hosted", "url": "https://pub.dev" },
      // ... 80+ packages
    }
  }
}
```

This is the maintenance burden: every Flutter update requires regenerating this entire structure. Nix partially automates it with `update.py` scripts.

---

## Appendix C: References

- Nixpkgs Flutter packaging: `pkgs/development/compilers/flutter/` in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs)
- Nixpkgs Android SDK: `pkgs/development/mobile/androidenv/` in NixOS/nixpkgs
- android-nixpkgs (daily-updated Nix flake): [tadfisher/android-nixpkgs](https://github.com/tadfisher/android-nixpkgs)
- Guix channel documentation: [GNU Guix Manual: Channels](https://guix.gnu.org/manual/en/html_node/Channels.html)
- Guix FHS emulation: [GNU Guix Manual: Invoking guix shell](https://guix.gnu.org/manual/en/html_node/Invoking-guix-shell.html)
- System Crafters Dart/Flutter attempt: [forum.systemcrafters.net](https://forum.systemcrafters.net/t/packaging-dart-flutter-for-gnu-guix/606)
- Existing Guix Android packages: `(gnu packages android)` module
