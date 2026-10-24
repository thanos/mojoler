#!/usr/bin/env bash
# Install the library into a clean consumer and a copied release.
# Does not publish to Hex. The release still needs the Mojo runtime that
# the .so was linked against. CPU consumers do not install MAX.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/examples/consumer"
mix deps.get
mix test
mix clean
mix test

cd "$root/examples/umbrella"
mix deps.get
mix test

cd "$root/examples/consumer"
MIX_ENV=prod mix release
dest="$(mktemp -d)/consumer"
cp -a "$root/examples/consumer/_build/prod/rel/consumer" "$dest"
got="$("$dest/bin/consumer" eval 'IO.write(Mojoler.POC.add(20, 22))')"
printf 'release %s\n' "$got"
if [[ "$got" != "42" ]]; then
  printf 'relocated release did not return 42\n' >&2
  exit 1
fi
printf 'release ok\n'
