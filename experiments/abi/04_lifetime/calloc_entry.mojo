# Module-level `var` is rejected by Mojo 1.1.0. calloc is how nif_init keeps
# the descriptor alive after it returns. This program checks that a string
# literal pointer still reads back after the allocating call.

from std.ffi import c_char, c_size_t, c_uint, external_call
from std.sys import size_of

@fieldwise_init
struct NameSlot(RegisterPassable):
    var name: Pointer[c_char, ImmStaticOrigin]
    var arity: c_uint

def main() raises:
    var mem = external_call[
        "calloc", Optional[Pointer[UInt8, MutUntrackedOrigin]]
    ](c_size_t(1), c_size_t(size_of[NameSlot]()))
    if not mem:
        raise Error("calloc failed")
    var slot = mem.value().unsafe_bitcast[NameSlot]()
    slot[] = NameSlot("add".as_c_string_span().ptr(), c_uint(2))
    print(String(unsafe_from_utf8_ptr=slot[].name))
    print("arity", slot[].arity)
    external_call["free", NoneType](mem.value().unsafe_bitcast[NoneType]())
