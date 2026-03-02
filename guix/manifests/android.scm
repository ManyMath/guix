;; Android development manifest.
;;
;; Enter this environment with:
;;   guix shell -m manifests/android.scm
;; Or reproducibly:
;;   guix time-machine -C manifests/channels.scm -- shell -m manifests/android.scm

(use-modules (gnu packages)
             (gnu packages base)
             (gnu packages certs)
             (gnu packages compression)
             (gnu packages curl)
             (gnu packages java)
             (gnu packages version-control)
             (guix profiles))

(define android-packages
  (map specification->package
       (list
        ;; Core build tools
        "git"
        "curl"
        "unzip"
        "xz"
        "which"
        "coreutils"
        "bash"

        ;; TLS certificates: needed by curl/sdkmanager inside the pure shell.
        "nss-certs"

        ;; JDK: Gradle and sdkmanager require Java 17.
        ;; The Android NDK provides its own clang toolchain,
        ;; so no system C/C++ compiler is needed.
        "openjdk@17")))

(packages->manifest android-packages)
