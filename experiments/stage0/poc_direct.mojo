# Direct Mojo implementation of an OTP 28 NIF for Elixir.Mojoler.POC.
#
# This file is the native library. It is compiled with:
#   mojo build native/poc.mojo --emit shared-lib -o priv/native/libpoc.so \
#     -Xlinker -undefined -Xlinker dynamic_lookup
# No C or C++ translation unit is part of that link.

from std.ffi import (
    c_char,
    c_int,
    c_long,
    c_size_t,
    c_uint,
    c_ulong,
    external_call,
)
from std.sys import size_of

# Layout matches erts-16.2 ErlNifFunc on LP64 Darwin (32 bytes, align 8).
# Origins do not change the ABI width: every pointer field is 8 bytes.
@fieldwise_init
struct NifFunc(RegisterPassable):
    var name: Pointer[c_char, ImmStaticOrigin]
    var arity: c_uint
    var fptr: def(
        env: Pointer[NoneType, MutUntrackedOrigin],
        argc: c_int,
        argv: Pointer[c_ulong, MutUntrackedOrigin],
    ) abi("C") thin -> c_ulong
    var flags: c_uint

# Layout matches erts-16.2 ErlNifEntry (96 bytes, align 8).
# Optional[Pointer] is 8 bytes here and None is the all-zero bit pattern,
# which is what the VM treats as a NULL callback.
@fieldwise_init
struct NifEntry(RegisterPassable):
    var major: c_int
    var minor: c_int
    var name: Pointer[c_char, ImmStaticOrigin]
    var num_of_funcs: c_int
    var funcs: Pointer[NifFunc, MutUntrackedOrigin]
    var load: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var reload: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var upgrade: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var unload: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var vm_variant: Pointer[c_char, ImmStaticOrigin]
    var options: c_uint
    var sizeof_resource_init: c_size_t
    var min_erts: Pointer[c_char, ImmStaticOrigin]


def badarg(env: Pointer[NoneType, MutUntrackedOrigin]) -> c_ulong:
    # enif_make_badarg is a real exported function. The VM turns the
    # returned term into an ArgumentError at the Elixir call boundary.
    return external_call["enif_make_badarg", c_ulong](env)


def fits_int64(a: c_long, b: c_long) -> Bool:
    # Overflow is badarg, not wrap. Comparisons stay inside the signed
    # range so the check itself cannot trap.
    # MIN is computed as -(2^63-1)-1 because the positive magnitude 2^63
    # is not a signed Int64 literal.
    comptime maxv = c_long(9223372036854775807)
    comptime min_mag = c_long(9223372036854775807)
    if b > 0 and a > (maxv - b):
        return False
    if b < 0:
        # b == INT64_MIN is the one negative value whose negation does not fit.
        # b + (2^63-1) == -1 exactly when b is INT64_MIN.
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
    # The VM passes env and argv only for this call. Nothing here stores them.
    if argc != 2:
        return badarg(env)
    var a = c_long(0)
    var b = c_long(0)
    # On this OTP, enif_get_int64 is a macro for enif_get_long. The symbol
    # beam.smp actually exports is enif_get_long(env, term, long*).
    var ok_a = external_call["enif_get_long", c_int](
        env, argv[unsafe_offset=0], Pointer(to=a)
    )
    var ok_b = external_call["enif_get_long", c_int](
        env, argv[unsafe_offset=1], Pointer(to=b)
    )
    if ok_a == 0 or ok_b == 0 or not fits_int64(a, b):
        return badarg(env)
    return external_call["enif_make_long", c_ulong](env, a + b)


def must_alloc(nbytes: c_size_t) -> Pointer[UInt8, MutUntrackedOrigin]:
    # Mojo 1.1.0 rejects module-level `var`, so the entry cannot live in a
    # Mojo global. calloc from libSystem gives the VM a stable address.
    # One allocation per process load; the VM keeps the pointer until unload.
    var mem = external_call[
        "calloc", Optional[Pointer[UInt8, MutUntrackedOrigin]]
    ](c_size_t(1), nbytes)
    if not mem:
        external_call["abort", NoneType]()
    return mem.value()


@export("nif_init")
def nif_init() abi("C") -> Pointer[NifEntry, MutUntrackedOrigin]:
    # Dynamic NIFs export nif_init, not Module_nif_init. OTP dlsym's that name.
    var funcs = must_alloc(c_size_t(size_of[NifFunc]())).unsafe_bitcast[NifFunc]()
    funcs[] = NifFunc(
        "add".as_c_string_span().ptr(), c_uint(2), add, c_uint(0)
    )
    var entry = must_alloc(c_size_t(size_of[NifEntry]())).unsafe_bitcast[NifEntry]()
    entry[] = NifEntry(
        c_int(2),
        c_int(17),
        "Elixir.Mojoler.POC".as_c_string_span().ptr(),
        c_int(1),
        funcs,
        None,
        None,
        None,
        None,
        "beam.vanilla".as_c_string_span().ptr(),
        c_uint(1),
        c_size_t(40),
        "erts-14.0".as_c_string_span().ptr(),
    )
    return entry
