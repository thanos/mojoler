# A thin C function is pointer-sized and can be stored in a struct field,
# then called back. Pointer(to=function) is NOT the code address: LLVM takes
# the address of a stack slot that holds the pointer. The field type below
# stores the code pointer itself.

from std.ffi import c_int
from std.sys import size_of

@fieldwise_init
struct Slot(RegisterPassable):
    var f: def(x: c_int) abi("C") thin -> c_int

def cb(x: c_int) abi("C") -> c_int:
    return x + 1

def main():
    var slot = Slot(cb)
    print("sizeof", size_of[Slot]())
    print("result", slot.f(c_int(41)))
