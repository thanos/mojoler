# Second NIF. It imports the generated ABI and does not restate the structs.

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


def double(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return enif_make_badarg(env)
    var a = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=0], Pointer(to=a)) == 0:
        return enif_make_badarg(env)
    if not fits_int64(a, a):
        return enif_make_badarg(env)
    return enif_make_long(env, a + a)


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(1)
    funcs[] = ErlNifFunc(
        "double".as_c_string_span().ptr(), c_uint(1), double, c_uint(0)
    )
    return make_entry(
        "Elixir.Mojoler.Twice".as_c_string_span().ptr(),
        funcs,
        c_int(1),
        None,
        None,
        None,
        None,
    )
