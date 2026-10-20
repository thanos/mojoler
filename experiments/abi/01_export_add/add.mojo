# Smallest C ABI export. This is not a NIF: there is no nif_init and no
# ErlNifEntry. It only proves mojo can emit a callable exported symbol.

@export("mojoler_add")
def mojoler_add(a: Int64, b: Int64) abi("C") -> Int64:
    return a + b
