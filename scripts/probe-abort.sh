#!/usr/bin/env bash
# Run an aborting NIF in a child BEAM. A zero exit is a failure of the probe.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$root/.venv/bin/mojo" build "$root/experiments/probes/abort.mojo" \
  --emit shared-lib \
  -I "$root/native" \
  -o "$tmp/libabort.so" \
  "${MOJO_LINK_FLAGS[@]}"

set +e
elixir -e '
defmodule Mojoler.AbortProbe do
  def load(path), do: :erlang.load_nif(String.to_charlist(path), 0)
  def boom, do: :erlang.nif_error(:nif_not_loaded)
end
:ok = Mojoler.AbortProbe.load("'"$tmp"'/libabort")
Mojoler.AbortProbe.boom()
' >"$tmp/out" 2>"$tmp/err"
status=$?
set -e

printf 'probe_exit %s\n' "$status"
if [[ "$status" -eq 0 ]]; then
  printf 'abort probe returned success\n' >&2
  exit 1
fi
printf 'probe ok\n'
