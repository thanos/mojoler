#!/usr/bin/env bash
# Regenerate the ABI, diff it, compare Mojo layout with clang, and reject a
# misspelled enif import. The C probe is compiled here and is not a NIF input.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="$root/.venv/bin/mojo"

python3 "$root/tools/abi/generate.py" --check

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/probe.c" <<'EOF'
#include "erl_nif.h"
#include <stddef.h>
#include <stdio.h>
int main(void) {
    printf("ErlNifFunc %zu %zu\n", sizeof(ErlNifFunc), _Alignof(ErlNifFunc));
    printf("field name %zu\n", offsetof(ErlNifFunc, name));
    printf("field arity %zu\n", offsetof(ErlNifFunc, arity));
    printf("field fptr %zu\n", offsetof(ErlNifFunc, fptr));
    printf("field flags %zu\n", offsetof(ErlNifFunc, flags));
    printf("ErlNifEntry %zu %zu\n", sizeof(ErlNifEntry), _Alignof(ErlNifEntry));
    printf("field major %zu\n", offsetof(ErlNifEntry, major));
    printf("field minor %zu\n", offsetof(ErlNifEntry, minor));
    printf("field name %zu\n", offsetof(ErlNifEntry, name));
    printf("field num_of_funcs %zu\n", offsetof(ErlNifEntry, num_of_funcs));
    printf("field funcs %zu\n", offsetof(ErlNifEntry, funcs));
    printf("field load %zu\n", offsetof(ErlNifEntry, load));
    printf("field reload %zu\n", offsetof(ErlNifEntry, reload));
    printf("field upgrade %zu\n", offsetof(ErlNifEntry, upgrade));
    printf("field unload %zu\n", offsetof(ErlNifEntry, unload));
    printf("field vm_variant %zu\n", offsetof(ErlNifEntry, vm_variant));
    printf("field options %zu\n", offsetof(ErlNifEntry, options));
    printf("field sizeof_ErlNifResourceTypeInit %zu\n", offsetof(ErlNifEntry, sizeof_ErlNifResourceTypeInit));
    printf("field min_erts %zu\n", offsetof(ErlNifEntry, min_erts));
    printf("ErlNifBinary %zu %zu\n", sizeof(ErlNifBinary), _Alignof(ErlNifBinary));
    printf("field size %zu\n", offsetof(ErlNifBinary, size));
    printf("field data %zu\n", offsetof(ErlNifBinary, data));
    printf("field ref_bin %zu\n", offsetof(ErlNifBinary, ref_bin));
    printf("field spare_0 %zu\n", offsetof(ErlNifBinary, __spare__));
    printf("ErlNifResourceTypeInit %zu %zu\n", sizeof(ErlNifResourceTypeInit), _Alignof(ErlNifResourceTypeInit));
    printf("field dtor %zu\n", offsetof(ErlNifResourceTypeInit, dtor));
    printf("field stop %zu\n", offsetof(ErlNifResourceTypeInit, stop));
    printf("field down %zu\n", offsetof(ErlNifResourceTypeInit, down));
    printf("field members %zu\n", offsetof(ErlNifResourceTypeInit, members));
    printf("field dyncall %zu\n", offsetof(ErlNifResourceTypeInit, dyncall));
    printf("ErlNifPid %zu %zu\n", sizeof(ErlNifPid), _Alignof(ErlNifPid));
    printf("field pid %zu\n", offsetof(ErlNifPid, pid));
    return 0;
}
EOF

"$CC_TOOL" -I "$ERL_NIF_INCLUDE" "$tmp/probe.c" -o "$tmp/probe"
"$tmp/probe" >"$tmp/c.txt"
"$mojo" -I "$root/native" "$root/tools/abi/print_layout.mojo" 2>"$tmp/mojo.err" | awk 'NF && $1 != "optional_none_or"' >"$tmp/mojo.txt"
# Mojo prints spare_1, which has no single C field. Drop it before the diff.
grep -v 'field spare_1' "$tmp/mojo.txt" >"$tmp/mojo.cmp"
if ! diff -u "$tmp/c.txt" "$tmp/mojo.cmp"; then
  printf 'layout mismatch\n' >&2
  exit 1
fi
printf 'layout ok\n'

"$mojo" build "$root/experiments/abi/negative/bad_import.mojo" \
  --emit shared-lib \
  -I "$root/native" \
  -o "$tmp/bad.so" \
  "${MOJO_LINK_FLAGS[@]}"
if "$root/scripts/check-imports.sh" "$tmp/bad.so"; then
  printf 'misspelled import was accepted\n' >&2
  exit 1
fi
printf 'misspelled import rejected\n'

shopt -s nullglob
libs=("$root"/priv/native/lib*.so)
if [[ "${#libs[@]}" -eq 0 ]]; then
  printf 'no native libraries to check\n' >&2
  exit 1
fi
for so in "${libs[@]}"; do
  "$root/scripts/check-imports.sh" "$so"
done

if grep -E '\.c($| )' "$root/priv/native/link-inputs.txt"; then
  printf 'diagnostic C is listed as a NIF input\n' >&2
  exit 1
fi
printf 'provenance ok\n'

"$CC_TOOL" -I "$ERL_NIF_INCLUDE" -xc -o "$tmp/flags" - <<'EOF'
#include "erl_nif.h"
#include <stdio.h>
int main(void) {
    printf("%d %d\n", ERL_NIF_DIRTY_JOB_CPU_BOUND, ERL_NIF_DIRTY_JOB_IO_BOUND);
    return 0;
}
EOF
"$tmp/flags" >"$tmp/cflags.txt"
python3 - "$root/native/mojoler/abi/otp_nif.mojo" >"$tmp/mflags.txt" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
def grab(name):
    match = re.search(rf"def {name}\(\) -> c_uint:\n    return c_uint\((\d+)\)", text)
    if not match:
        raise SystemExit(f"missing {name}")
    return match.group(1)
print(grab("abi_dirty_cpu"), grab("abi_dirty_io"))
PY
if ! diff -u "$tmp/cflags.txt" "$tmp/mflags.txt"; then
  printf 'dirty flags differ from the header\n' >&2
  exit 1
fi
printf 'dirty flags ok\n'
