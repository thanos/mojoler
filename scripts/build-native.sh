#!/usr/bin/env bash
# Build the direct-Mojo NIF. Diagnostic C under experiments/ is not an input.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="$root/.venv/bin/mojo"

if [[ ! -x "$mojo" ]]; then
  printf 'mojo is not installed at %s\n' "$mojo" >&2
  printf 'run: uv venv && uv pip install -r requirements.txt\n' >&2
  exit 1
fi

mkdir -p "$root/priv/native"

"$mojo" build "$root/native/poc.mojo" \
  --emit shared-lib \
  -o "$root/priv/native/libpoc.so" \
  "${MOJO_LINK_FLAGS[@]}"
