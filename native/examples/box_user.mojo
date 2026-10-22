# Author code for the resource example. The wrapper owns the resource.

from std.ffi import c_long


def step(value: c_long, delta: c_long) -> c_long:
    return value + delta
