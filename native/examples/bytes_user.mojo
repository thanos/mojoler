# Author code for the binary example. One function transforms a byte.
# The wrapper decides whether the payload is copied.

from std.ffi import c_int


def shift_byte(byte: UInt8) -> UInt8:
    var n = Int(byte) + 1
    if n == 256:
        n = 0
    return UInt8(n)


def borrowed_len(size: c_int) -> c_int:
    return size
