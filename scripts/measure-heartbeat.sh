#!/usr/bin/env bash
# Compare a dirty-CPU burn with a normal-scheduler burn in a one-scheduler VM.
# The normal library is built in a temp directory and is not a product input.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="$root/.venv/bin/mojo"

if [[ "${MOJOLER_SKIP_BUILD:-}" != 1 ]]; then
  bash "$root/scripts/build-native.sh" >/dev/null
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$mojo" build "$root/experiments/sched/normal_burn.mojo" \
  --emit shared-lib \
  -I "$root/native" \
  -o "$tmp/libnormal.so" \
  "${MOJO_LINK_FLAGS[@]}"

run_mode() {
  local mode="$1"
  local path="$2"
  elixir --erl "+S 1" "$root/experiments/sched/measure.exs" "$mode" "$path"
}

dirty="$(run_mode dirty "$root/priv/native/libsched")"
normal="$(run_mode normal "$tmp/libnormal")"
printf '%s\n' "$dirty"
printf '%s\n' "$normal"

dirty_beats="$(awk '{print $2}' <<<"$dirty")"
normal_beats="$(awk '{print $2}' <<<"$normal")"

if [[ "$dirty_beats" -lt 1 ]]; then
  printf 'dirty scheduler produced no heartbeats\n' >&2
  exit 1
fi
if [[ "$normal_beats" -ne 0 ]]; then
  printf 'normal scheduler still produced heartbeats: %s\n' "$normal_beats" >&2
  exit 1
fi
printf 'heartbeat ok dirty=%s normal=%s\n' "$dirty_beats" "$normal_beats"
