# Dirty-scheduler jobs for Elixir.Mojoler.Sched.
# Flags come from the generated ABI constants. A borrowed binary view is
# released before the CPU loop. The loop holds an owned buffer.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong, external_call
from std.sys import size_of

from mojoler.abi.otp_nif import (
    ErlNifBinary,
    ErlNifEntry,
    ErlNifFunc,
    abi_dirty_cpu,
    abi_dirty_io,
    enif_get_long,
    enif_inspect_binary,
    enif_make_atom,
    enif_make_badarg,
    enif_make_new_binary,
)
from mojoler.abi.prim import alloc_funcs, make_entry, must_alloc, must_free


def lit(text: StaticString) -> Pointer[c_char, ImmStaticOrigin]:
    return text.as_c_string_span().ptr()


def millis() -> c_long:
    # ERL_NIF_MSEC is 1 in this OTP. The unit is an argument, not a header struct.
    return external_call["enif_monotonic_time", c_long](c_int(1))


def spin(ms: c_long):
    var start = millis()
    var steps = c_long(0)
    while millis() - start < ms:
        steps = steps + c_long(1)
    _ = steps


def burn(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return enif_make_badarg(env)
    var ms = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=0], Pointer(to=ms)) == 0 or ms < 0:
        return enif_make_badarg(env)
    spin(ms)
    return enif_make_atom(env, lit("ok"))


def hold(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 2:
        return enif_make_badarg(env)
    var ms = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=1], Pointer(to=ms)) == 0 or ms < 0:
        return enif_make_badarg(env)
    var inspected = must_alloc(c_size_t(size_of[ErlNifBinary]())).unsafe_bitcast[ErlNifBinary]()
    if enif_inspect_binary(env, argv[unsafe_offset=0], inspected) == 0:
        must_free(inspected)
        return enif_make_badarg(env)
    var n = Int(inspected[].size)
    var owned = must_alloc(c_size_t(n if n > 0 else 1))
    var i = 0
    while i < n:
        owned[unsafe_offset=i] = inspected[].data[unsafe_offset=i]
        i += 1
    # The borrowed view ends here. The spin only reads the owned buffer.
    must_free(inspected)
    spin(ms)
    var term = c_ulong(0)
    var out = enif_make_new_binary(env, c_size_t(n), Pointer(to=term))
    i = 0
    while i < n:
        out[unsafe_offset=i] = owned[unsafe_offset=i]
        i += 1
    must_free(owned)
    return term


def io_ping(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argv
    if argc != 0:
        return enif_make_badarg(env)
    return enif_make_atom(env, lit("ok"))


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(3)
    funcs[unsafe_offset=0] = ErlNifFunc(lit("burn"), c_uint(1), burn, abi_dirty_cpu())
    funcs[unsafe_offset=1] = ErlNifFunc(lit("hold"), c_uint(2), hold, abi_dirty_cpu())
    funcs[unsafe_offset=2] = ErlNifFunc(lit("io_ping"), c_uint(0), io_ping, abi_dirty_io())
    return make_entry(
        lit("Elixir.Mojoler.Sched"),
        funcs,
        c_int(3),
        None,
        None,
        None,
        None,
    )
