# Disposable trap. scripts/probe-abort.sh loads this in a child BEAM.
# The product libraries do not call abort on a caller-visible path.

from std.ffi import c_char, c_int, c_uint, c_ulong, external_call

from mojoler.abi.otp_nif import ErlNifEntry, ErlNifFunc
from mojoler.abi.prim import alloc_funcs, make_entry


def boom(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = env
    _ = argc
    _ = argv
    external_call["abort", NoneType]()
    return c_ulong(0)


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(1)
    funcs[] = ErlNifFunc(
        "boom".as_c_string_span().ptr(), c_uint(0), boom, c_uint(0)
    )
    return make_entry(
        "Elixir.Mojoler.AbortProbe".as_c_string_span().ptr(),
        funcs,
        c_int(1),
        None,
        None,
        None,
        None,
    )
