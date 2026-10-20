# Shared platform facts for the NIF build. Source from bash; do not execute.
# Darwin binds undefined enif_* symbols only with flat lookup. ELF ld.so
# resolves them against beam.smp when the shared library allows undefined
# symbols. The Linux flag is the intended link line; a green GitHub Actions
# run is what promotes it from a hypothesis to evidence.

erl_root="$(erl -noshell -eval 'io:format("~s",[code:root_dir()]), halt().' 2>/dev/null || true)"
if [[ -n "$erl_root" ]]; then
  ERL_NIF_H="$(find "$erl_root" -name erl_nif.h -path '*/include/erl_nif.h' -print -quit 2>/dev/null || true)"
else
  ERL_NIF_H=""
fi
if [[ -n "${ERL_NIF_H}" ]]; then
  ERL_NIF_INCLUDE="$(dirname "$ERL_NIF_H")"
else
  ERL_NIF_INCLUDE=""
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  MOJO_LINK_FLAGS=(-Xlinker -undefined -Xlinker dynamic_lookup)
else
  # ignore-in-shared-libs still errors on undefined symbols that come from
  # the Mojo archive itself. CI run 39365275751 failed that way on
  # enif_make_long. ignore-all is the GNU ld switch that leaves those
  # symbols for ld.so to bind when beam.smp loads the library. -z undefs
  # cancels -z defs if the compiler driver passes that.
  MOJO_LINK_FLAGS=(
    -Xlinker --unresolved-symbols=ignore-all
    -Xlinker -z
    -Xlinker undefs
  )
fi

if command -v clang >/dev/null 2>&1; then
  CC_TOOL="clang"
elif command -v cc >/dev/null 2>&1; then
  CC_TOOL="cc"
else
  CC_TOOL=""
fi
