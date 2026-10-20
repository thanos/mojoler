# Calls initialize_runtime twice from nif_init, then returns a constant term.
# This is a separate library from priv/native/libpoc.so. The add NIF does not
# call initialize_runtime.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong, external_call
from std.runtime import initialize_runtime
from std.sys import size_of

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

def ping(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argc
    _ = argv
    return external_call["enif_make_long", c_ulong](env, c_long(7))

def must_alloc(nbytes: c_size_t) -> Pointer[UInt8, MutUntrackedOrigin]:
    var mem = external_call["calloc", Optional[Pointer[UInt8, MutUntrackedOrigin]]](
        c_size_t(1), nbytes
    )
    if not mem:
        external_call["abort", NoneType]()
    return mem.value()

@export("nif_init")
def nif_init() abi("C") -> Pointer[NifEntry, MutUntrackedOrigin]:
    initialize_runtime()
    initialize_runtime()
    var funcs = must_alloc(c_size_t(size_of[NifFunc]())).unsafe_bitcast[NifFunc]()
    funcs[] = NifFunc("ping".as_c_string_span().ptr(), c_uint(0), ping, c_uint(0))
    var entry = must_alloc(c_size_t(size_of[NifEntry]())).unsafe_bitcast[NifEntry]()
    entry[] = NifEntry(
        c_int(2),
        c_int(17),
        "Elixir.Mojoler.RuntimeProbe".as_c_string_span().ptr(),
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
