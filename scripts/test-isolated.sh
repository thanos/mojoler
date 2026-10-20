#!/usr/bin/env bash
# Run mix test in this process, under a hard alarm, so a wedged or crashing
# BEAM cannot hang the caller. macOS does not ship GNU timeout.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

exec perl -e 'alarm shift; exec @ARGV' 180 mix test
