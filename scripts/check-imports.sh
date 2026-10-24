#!/usr/bin/env bash
# Fail if a shared library has an undefined symbol outside the reviewed set.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
so="${1:?shared library path}"

allow="$(mktemp)"
trap 'rm -f "$allow"' EXIT
grep -v '^#' "$root/tools/abi/compiler_imports.txt" | awk 'NF' >"$allow"
awk 'NF && $1 !~ /^#/' "$root/tools/abi/functions.txt" >>"$allow"

if [[ "$(uname -s)" == "Darwin" ]]; then
  # Mach-O prefixes defined C names with _. nm -u prints that underscore.
  undefined="$(nm -u "$so" | awk '{print $NF}' | sed 's/^_//')"
else
  # glibc versions the symbol: abort@GLIBC_2.2.5. The allowlist names the symbol.
  undefined="$(nm -u "$so" | awk '{print $NF}' | sed 's/@.*//')"
fi

bad=0
while IFS= read -r sym; do
  [[ -z "$sym" ]] && continue
  if ! grep -qx "$sym" "$allow"; then
    printf 'unexpected undefined symbol: %s\n' "$sym" >&2
    bad=1
  fi
done <<<"$undefined"

if [[ "$bad" -ne 0 ]]; then
  exit 1
fi
printf 'imports ok %s\n' "$so"
