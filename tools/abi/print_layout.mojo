# Host layout of the generated structs. Compared with the clang probe.
# This program is not linked into a NIF.

from std.reflection import reflect
from std.sys import align_of, size_of

from mojoler.abi.otp_nif import (
    ErlNifBinary,
    ErlNifEntry,
    ErlNifFunc,
    ErlNifPid,
    ErlNifResourceTypeInit,
)


def show[T: AnyType](label: String):
    print(label, size_of[T](), align_of[T]())
    var names = materialize[reflect[T].field_names()]()
    comptime for i in range(reflect[T].field_count()):
        comptime off = reflect[T].field_offset[index=i]()
        print("field", names[i], off)


def main():
    show[ErlNifFunc]("ErlNifFunc")
    show[ErlNifEntry]("ErlNifEntry")
    show[ErlNifBinary]("ErlNifBinary")
    show[ErlNifResourceTypeInit]("ErlNifResourceTypeInit")
    show[ErlNifPid]("ErlNifPid")
    var none = Optional[Pointer[NoneType, MutUntrackedOrigin]](None)
    var raw = Pointer(to=none).unsafe_bitcast[UInt8]()
    var acc = 0
    for i in range(8):
        acc = acc | Int(raw[unsafe_offset=i])
    print("optional_none_or", acc)
