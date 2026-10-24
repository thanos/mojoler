# Unsafe helpers shared by every NIF. Preconditions are stated on each def.
# These functions do not check Elixir terms. Callers in the checked layer do.

from std.ffi import c_char, c_int, c_size_t, external_call
from std.sys import size_of

from mojoler.abi.otp_nif import (
    ErlNifEntry,
    ErlNifFunc,
    ErlNifResourceTypeInit,
    abi_major,
    abi_min_erts,
    abi_minor,
    abi_options,
    abi_vm_variant,
)

def must_alloc(nbytes: c_size_t) -> Pointer[UInt8, MutUntrackedOrigin]:
    # calloc is the paired allocator for the descriptor blocks. Failure aborts
    # because a NIF with no entry cannot return a term. Stage 3 audits this.
    var mem = external_call[
        "calloc", Optional[Pointer[UInt8, MutUntrackedOrigin]]
    ](c_size_t(1), nbytes)
    if not mem:
        external_call["abort", NoneType]()
    return mem.value()


def must_free[o: Origin, T: AnyType](mem: Pointer[T, o]):
    # Pair of must_alloc. enif_free is a different allocator and must not be used here.
    external_call["free", NoneType](mem.unsafe_bitcast[NoneType]())


def callback_opt(bits: Int) -> Optional[Pointer[NoneType, MutUntrackedOrigin]]:
    # `bits` is the code address of a thin C function, or 0 for NULL.
    # Optional[Pointer] is the 8-byte NULL representation measured in Stage 0.
    if bits == 0:
        return None
    return Pointer[NoneType, MutUntrackedOrigin](unsafe_from_address=bits)


def make_entry(
    name: Pointer[c_char, ImmStaticOrigin],
    funcs: Pointer[ErlNifFunc, MutUntrackedOrigin],
    count: c_int,
    load: Optional[Pointer[NoneType, MutUntrackedOrigin]],
    reload: Optional[Pointer[NoneType, MutUntrackedOrigin]],
    upgrade: Optional[Pointer[NoneType, MutUntrackedOrigin]],
    unload: Optional[Pointer[NoneType, MutUntrackedOrigin]],
) -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var entry = must_alloc(c_size_t(size_of[ErlNifEntry]())).unsafe_bitcast[ErlNifEntry]()
    entry[] = ErlNifEntry(
        abi_major(),
        abi_minor(),
        name,
        count,
        funcs,
        load,
        reload,
        upgrade,
        unload,
        abi_vm_variant(),
        abi_options(),
        c_size_t(size_of[ErlNifResourceTypeInit]()),
        abi_min_erts(),
    )
    return entry


def alloc_funcs(count: Int) -> Pointer[ErlNifFunc, MutUntrackedOrigin]:
    var bytes = c_size_t(size_of[ErlNifFunc]() * count)
    return must_alloc(bytes).unsafe_bitcast[ErlNifFunc]()
