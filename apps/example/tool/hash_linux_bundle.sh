#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_FILE_DEFAULT="$ROOT_DIR/expected-hashes/linux-x86_64.sha256"

bundle_dir="$(
  find "$ROOT_DIR/build/linux" -type d -path '*/release/bundle' 2>/dev/null \
    | LC_ALL=C sort \
    | head -n 1
)"

if [ -z "$bundle_dir" ]; then
  echo "Linux release bundle not found. Run: make guix-build" >&2
  exit 1
fi

actual_hash="$(
  tar \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --mode='u+rwX,go+rX,go-w' \
    --format=gnu \
    -cf - \
    -C "$bundle_dir" \
    . \
    | sha256sum \
    | awk '{print $1}'
)"

if [ "${1:-}" = "--check" ]; then
  expected_file="${2:-$EXPECTED_FILE_DEFAULT}"
  if [ ! -f "$expected_file" ]; then
    echo "Expected hash file not found: $expected_file" >&2
    exit 1
  fi

  expected_hash="$(awk 'NF { print $1; exit }' "$expected_file")"

  echo "Bundle:   $bundle_dir"
  echo "Actual:   $actual_hash"
  echo "Expected: $expected_hash"

  if [ "$actual_hash" != "$expected_hash" ]; then
    echo "Hash mismatch." >&2
    exit 1
  fi

  echo "Hash verified."
  exit 0
fi

printf '%s\n' "$actual_hash"
