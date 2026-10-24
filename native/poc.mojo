# Elixir.Mojoler.POC.add/2. The struct declarations come from the generated
# ABI module. The arithmetic and the badarg policy are the Stage 0 contract.
# experiments/stage0/poc_direct.mojo is the pre-extraction copy.

from std.ffi import c_int, c_long, c_uint, c_ulong

from mojoler.abi.otp_nif import (
    ErlNifEntry,
    ErlNifFunc,
    enif_get_long,
    enif_make_badarg,
    enif_make_long,
)
from mojoler.abi.prim import alloc_funcs, make_entry


def fits_int64(a: c_long, b: c_long) -> Bool:
    comptime maxv = c_long(9223372036854775807)
    comptime min_mag = c_long(9223372036854775807)
    if b > 0 and a > (maxv - b):
        return False
    if b < 0:
        if a < 0 and (b + min_mag) == -1:
            return False
        var limit = (c_long(0) - min_mag - c_long(1)) - b
        if a < limit:
            return False
    return True


def add(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 2:
        return enif_make_badarg(env)
    var a = c_long(0)
    var b = c_long(0)
    var ok_a = enif_get_long(env, argv[unsafe_offset=0], Pointer(to=a))
    var ok_b = enif_get_long(env, argv[unsafe_offset=1], Pointer(to=b))
    if ok_a == 0 or ok_b == 0 or not fits_int64(a, b):
        return enif_make_badarg(env)
    return enif_make_long(env, a + b)


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(1)
    funcs[] = ErlNifFunc(
        "add".as_c_string_span().ptr(), c_uint(2), add, c_uint(0)
    )
    return make_entry(
        "Elixir.Mojoler.POC".as_c_string_span().ptr(),
        funcs,
        c_int(1),
        None,
        None,
        None,
        None,
    )
