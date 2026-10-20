#!/usr/bin/env bash
# Print the symbols and shared-library dependencies of the built NIF.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
so="$root/priv/native/libpoc.so"

if [[ ! -f "$so" ]]; then
  "$root/scripts/build-native.sh"
fi

printf '== file ==\n'
file "$so"

if [[ "$(uname -s)" == "Darwin" ]]; then
  printf '\n== nm -gU (exported definitions) ==\n'
  nm -gU "$so"
  printf '\n== nm -u (undefined symbols) ==\n'
  nm -u "$so"
  printf '\n== otool -L ==\n'
  otool -L "$so"
  printf '\n== otool -l rpath ==\n'
  otool -l "$so" | awk '/LC_RPATH/,/path /'
else
  printf '\n== nm -g --defined-only ==\n'
  nm -g --defined-only "$so"
  printf '\n== nm -u (undefined symbols) ==\n'
  nm -u "$so"
  printf '\n== ldd ==\n'
  ldd "$so"
  printf '\n== readelf NEEDED ==\n'
  if command -v readelf >/dev/null 2>&1; then
    readelf -d "$so" | awk '/NEEDED|RPATH|RUNPATH/'
  fi
fi
