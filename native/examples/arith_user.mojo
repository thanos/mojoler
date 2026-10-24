# Author code for the arithmetic example. The generated wrapper decodes the
# terms and calls this function. This file does not mention ErlNifEntry.

from std.ffi import c_int, c_long


@fieldwise_init
struct AddResult(RegisterPassable):
    var ok: c_int
    var value: c_long


def checked_add(a: c_long, b: c_long) -> AddResult:
    comptime maxv = c_long(9223372036854775807)
    comptime min_mag = c_long(9223372036854775807)
    if b > 0 and a > (maxv - b):
        return AddResult(c_int(0), c_long(0))
    if b < 0:
        if a < 0 and (b + min_mag) == -1:
            return AddResult(c_int(0), c_long(0))
        var limit = (c_long(0) - min_mag - c_long(1)) - b
        if a < limit:
            return AddResult(c_int(0), c_long(0))
    return AddResult(c_int(1), a + b)
