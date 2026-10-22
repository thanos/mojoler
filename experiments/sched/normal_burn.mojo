# Disposable normal-scheduler control. Not a product library.
# scripts/measure-heartbeat.sh builds this into a temp directory and runs it
# in a one-scheduler VM. The product burn lives in native/sched.mojo.

from std.ffi import c_char, c_int, c_long, c_uint, c_ulong, external_call

from mojoler.abi.otp_nif import ErlNifEntry, ErlNifFunc, enif_get_long, enif_make_atom, enif_make_badarg
from mojoler.abi.prim import alloc_funcs, make_entry


def lit(text: StaticString) -> Pointer[c_char, ImmStaticOrigin]:
    return text.as_c_string_span().ptr()


def millis() -> c_long:
    return external_call["enif_monotonic_time", c_long](c_int(1))


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
    var start = millis()
    var steps = c_long(0)
    while millis() - start < ms:
        steps = steps + c_long(1)
    _ = steps
    return enif_make_atom(env, lit("ok"))


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(1)
    funcs[] = ErlNifFunc(lit("burn"), c_uint(1), burn, c_uint(0))
    return make_entry(
        lit("Elixir.Mojoler.Normal"),
        funcs,
        c_int(1),
        None,
        None,
        None,
        None,
    )
