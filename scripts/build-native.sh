#!/usr/bin/env bash
# Build the direct-Mojo NIF. Diagnostic C under experiments/ is not an input.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="${MOJO:-}"

if [[ -z "$mojo" || ! -x "$mojo" ]]; then
  printf 'mojo is not installed\n' >&2
  printf 'put mojo on PATH, or run: uv venv && uv pip install -r requirements.txt\n' >&2
  exit 1
fi

out="${MOJOLER_OUT:-$root/priv/native}"
mkdir -p "$out"

# Only .mojo sources are inputs. The diagnostic C probe is not in this list.
inputs=(
  "$root/native/poc.mojo"
  "$root/native/twice.mojo"
  "$root/native/term.mojo"
  "$root/native/own.mojo"
  "$root/native/sched.mojo"
  "$root/native/generated/arith.mojo"
  "$root/native/generated/bytes.mojo"
  "$root/native/generated/box.mojo"
)
printf '%s\n' "${inputs[@]}" >"$out/link-inputs.txt"

build_one() {
  local src="$1"
  local out="$2"
  "$mojo" build "$src" \
    --emit shared-lib \
    -I "$root/native" \
    -o "$out" \
    "${MOJO_LINK_FLAGS[@]}"
}

build_one "$root/native/poc.mojo" "$out/libpoc.so"
build_one "$root/native/twice.mojo" "$out/libtwice.so"
build_one "$root/native/term.mojo" "$out/libterm.so"
build_one "$root/native/own.mojo" "$out/libown.so"
build_one "$root/native/sched.mojo" "$out/libsched.so"
build_one "$root/native/generated/arith.mojo" "$out/libdsl_arith.so"
build_one "$root/native/generated/bytes.mojo" "$out/libdsl_bytes.so"
build_one "$root/native/generated/box.mojo" "$out/libdsl_box.so"
