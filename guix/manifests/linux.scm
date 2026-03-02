;; Linux (Ubuntu 24.04 target) development manifest.
;;
;; Enter this environment with:
;;   guix shell -m manifests/linux.scm
;; Or reproducibly:
;;   guix time-machine -C manifests/channels.scm -- shell -m manifests/linux.scm

(use-modules (gnu packages)
             (gnu packages base)
             (gnu packages commencement)   ; gcc-toolchain
             (gnu packages llvm)           ; clang-toolchain
             (gnu packages cmake)
             (gnu packages ninja)
             (gnu packages pkg-config)
             (gnu packages gtk)            ; gtk+, pango, cairo, harfbuzz, gdk-pixbuf
             (gnu packages glib)
             (gnu packages gl)             ; mesa, libepoxy
             (gnu packages fontutils)      ; fontconfig, freetype
             (gnu packages freedesktop)    ; at-spi2-core
             (gnu packages xorg)
             (gnu packages compression)    ; xz, zlib
             (gnu packages version-control)
             (gnu packages curl)
             (gnu packages xdisorg)        ; libxkbcommon
             (guix profiles))

(define common-packages
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

        ;; C/C++ toolchain (Flutter Linux uses clang)
        "clang-toolchain"
        "gcc-toolchain@13" ; pin to 13: GCC 14's libstdc++ headers use
                           ; _GLIBCXX_USE_BUILTIN_TRAIT which clang < 18
                           ; cannot parse

        ;; Build systems
        "cmake"
        "ninja"
        "pkg-config")))

(define linux-packages
  (map specification->package
       (list
        ;; GTK 3: Flutter Linux embedding
        "gtk+"              ; gtk+3 in Guix
        "glib"
        "pango"
        "cairo"
        "gdk-pixbuf"
        "harfbuzz"

        ;; OpenGL / EGL
        "mesa"
        "libepoxy"

        ;; Fonts
        "fontconfig"
        "freetype"

        ;; Accessibility
        "at-spi2-core"

        ;; X11 libs (Flutter Linux runner links against these)
        "libx11"
        "libxext"
        "libxrandr"
        "libxcursor"
        "libxfixes"
        "libxi"
        "libxinerama"
        "libxcomposite"
        "libxdamage"
        "libxrender"
        "libxtst"

        ;; Keyboard / Wayland
        "libxkbcommon"

        ;; Misc system libs
        "zlib"
        "dbus")))

(packages->manifest
 (append common-packages linux-packages))
