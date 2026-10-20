Decision: a `def ... abi("C") thin` value is 8 bytes and can be stored and called. `Pointer(to=function)` is the address of a stack slot, so it must not be written into `ErlNifFunc.fptr`.
