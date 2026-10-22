#!/usr/bin/env bash
# One line. Changes when a NIF input, the generator, the headers, or the
# compiler does. Identical inputs print the same line.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  printf 'mojo '
  if [[ -n "${MOJO:-}" ]]; then
    "$MOJO" --version 2>/dev/null | head -n 1
  else
    printf 'missing\n'
  fi
  printf 'triple '
  "$CC_TOOL" -dumpmachine
  printf 'flags'
  printf ' %s' "${MOJO_LINK_FLAGS[@]}"
  printf '\nheader %s\n' "$(hash_file "$ERL_NIF_INCLUDE/erl_nif.h")"
  find "$root/native" "$root/tools/abi" "$root/scripts/build-native.sh" "$root/scripts/env.sh" \
    -type f ! -name manifest.json ! -name FINGERPRINT \
    | sort \
    | while IFS= read -r file; do
        printf '%s %s\n' "$(hash_file "$file")" "${file#"$root"/}"
      done
} >"$tmp"

hash_file "$tmp"
