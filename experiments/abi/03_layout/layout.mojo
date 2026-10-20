# Mojo's view of the same field order as ErlNifFunc and ErlNifEntry.
# Compare the numbers with experiments/abi/diagnostic/layout.c.

from std.ffi import c_char, c_int, c_size_t, c_uint, c_ulong
from std.reflection import reflect
from std.sys import align_of, size_of

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

def show[T: AnyType](label: String):
    print(label, "sizeof", size_of[T](), "align", align_of[T]())
    var names = materialize[reflect[T].field_names()]()
    comptime for i in range(reflect[T].field_count()):
        comptime off = reflect[T].field_offset[index=i]()
        print(" ", names[i], off)

def main():
    show[NifFunc]("NifFunc")
    show[NifEntry]("NifEntry")
    var none = Optional[Pointer[NoneType, MutUntrackedOrigin]](None)
    var raw = Pointer(to=none).unsafe_bitcast[UInt8]()
    var acc = 0
    for i in range(8):
        acc = acc | Int(raw[unsafe_offset=i])
    print("optional_none_or", acc)
    print("literal", String(unsafe_from_utf8_ptr="Elixir.Mojoler.POC".as_c_string_span().ptr()))
