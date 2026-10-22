# Negative control. enif_make_lonq is not an OTP symbol. The import gate must
# reject this library even though the Linux link line allows unresolved symbols.

from std.ffi import c_ulong, external_call


def bad(env: Pointer[NoneType, MutUntrackedOrigin]) -> c_ulong:
    return external_call["enif_make_lonq", c_ulong](env)


@export("nif_init")
def nif_init() abi("C") -> c_ulong:
    return bad(Pointer[NoneType, MutUntrackedOrigin](unsafe_from_address=1))
