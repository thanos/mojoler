#!/usr/bin/env bash
# Re-run the ABI experiments and write their observed output next to the source.
# The diagnostic C program is compiled and executed here. It is not linked
# into priv/native/libpoc.so.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="$root/.venv/bin/mojo"
out="$root/experiments/abi/OBSERVED.txt"

if [[ "$(uname -s)" == "Darwin" ]]; then
  add_lib="$root/experiments/abi/01_export_add/libadd.dylib"
else
  add_lib="$root/experiments/abi/01_export_add/libadd.so"
fi

{
  printf '== 01 export add ==\n'
  "$mojo" build "$root/experiments/abi/01_export_add/add.mojo" \
    --emit shared-lib \
    -o "$add_lib"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    nm -gU "$add_lib"
    otool -L "$add_lib"
  else
    nm -g --defined-only "$add_lib"
    ldd "$add_lib"
  fi
  "$mojo" build "$root/experiments/abi/01_export_add/add.mojo" \
    --emit llvm \
    -o "$root/experiments/abi/01_export_add/add.ll"
  printf 'llvm bytes %s\n' "$(wc -c < "$root/experiments/abi/01_export_add/add.ll")"

  printf '\n== 02 thin callback ==\n'
  "$mojo" "$root/experiments/abi/02_pointers/callback.mojo"

  printf '\n== 03 layout ==\n'
  "$mojo" "$root/experiments/abi/03_layout/layout.mojo"

  printf '\n== diagnostic C (not linked into the NIF) ==\n'
  if [[ -z "$CC_TOOL" || -z "$ERL_NIF_INCLUDE" ]]; then
    printf 'diagnostic C skipped: compiler or erl_nif.h missing\n'
    exit 1
  fi
  "$CC_TOOL" -I "$ERL_NIF_INCLUDE" \
    -o "$root/experiments/abi/diagnostic/layout" \
    "$root/experiments/abi/diagnostic/layout.c"
  "$root/experiments/abi/diagnostic/layout"

  printf '\n== 04 calloc lifetime ==\n'
  "$mojo" "$root/experiments/abi/04_lifetime/calloc_entry.mojo"

  printf '\n== 05 runtime init inside a fresh BEAM ==\n'
  "$mojo" build "$root/experiments/abi/05_runtime/rtnif.mojo" \
    --emit shared-lib \
    -o "$root/experiments/abi/05_runtime/librt.so" \
    "${MOJO_LINK_FLAGS[@]}"
  elixir -e '
    defmodule Mojoler.RuntimeProbe do
      @on_load :load_nif
      def load_nif, do: :erlang.load_nif(~c"'"$root"'/experiments/abi/05_runtime/librt", 0)
      def ping, do: :erlang.nif_error(:nif_not_loaded)
    end
    IO.puts("runtime ping #{Mojoler.RuntimeProbe.ping()}")
  '

  printf '\n== 06-08 nif_init, enif symbols, dlopen ==\n'
  printf 'Covered by scripts/build-native.sh, scripts/inspect-abi.sh, and mix test.\n'
} >"$out" 2>&1

cat "$out"
