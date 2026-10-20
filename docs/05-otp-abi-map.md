# 05 — OTP ABI map for erts 16.2

## Learning objectives

- Read a measured offset table and refuse to "clean it up" from memory.
- Point at the C program that produced the numbers and the Mojo program that matched them.

## Why this matters

`ErlNifEntry` has `int` fields next to pointers. On arm64 those ints are 4 bytes and pointers want 8-byte alignment, so the compiler inserts padding. A Mojo struct that "has the same fields" in a different order, or that uses a 16-byte optional function, loads garbage for every field after the mistake. The VM then rejects the library, or worse, jumps to a pointer it read from padding.

## Mental model

```text
offset 0        4        8        16
ErlNifFunc:  name........ arity.... (pad) fptr........ flags... (pad to 32)

offset 0   4   8        16  20  24       32 ...
ErlNifEntry: maj min name....  nfuncs (pad) funcs.... callbacks....
```

## Theory

All numbers below are from `experiments/abi/diagnostic/layout.c` compiled against `erts-16.2/include` and executed on this Mac. The Mojo mirrors in `experiments/abi/03_layout/layout.mojo` printed the same sizes and the same field offsets.

Widths: pointer 8, int 4, unsigned 4, long 8, size_t 8. `ERL_NIF_TERM` is 8.

`ErlNifFunc`, size 32, align 8:

- `name` offset 0, size 8, `const char*`
- `arity` offset 8, size 4, `unsigned`
- `fptr` offset 16, size 8, function pointer `(ErlNifEnv*, int, const ERL_NIF_TERM*) -> ERL_NIF_TERM`
- `flags` offset 24, size 4, `unsigned`
- 4 bytes of tail padding

`ErlNifEntry`, size 96, align 8:

- `major` 0, `minor` 4, both `int`. Values 2 and 17.
- `name` 8, `const char*`. Value `Elixir.Mojoler.POC`.
- `num_of_funcs` 16, `int`. Value 1. Four bytes of padding follow, so `funcs` is at 24.
- `funcs` 24, pointer to the `ErlNifFunc` array.
- `load` 32, `reload` 40, `upgrade` 48, `unload` 56. NULL in this NIF.
- `vm_variant` 64. `"beam.vanilla"`.
- `options` 72, `unsigned`. The header's `ERL_NIF_INIT` stores 1.
- `sizeof_ErlNifResourceTypeInit` 80, `size_t`. Measured sizeof of that struct is 40.
- `min_erts` 88. `"erts-14.0"`.

`ErlNifResourceTypeInit`, size 40, align 8: dtor 0, stop 8, down 16, members 24 (int), dyncall 32. Not constructed by the NIF. Only its size is stored.

Dirty flags, from the same run: CPU 1, IO 2.

Init symbol: `nif_init`, no arguments, returns `ErlNifEntry*`, default visibility. Darwin symbol table name: `_nif_init`.

API symbols the callback calls:

- `int enif_get_long(ErlNifEnv*, ERL_NIF_TERM, long*)`
- `ERL_NIF_TERM enif_make_long(ErlNifEnv*, long)`
- `ERL_NIF_TERM enif_make_badarg(ErlNifEnv*)`

`enif_get_int64` and `enif_make_int64` are macros for those long functions when `SIZEOF_LONG == 8`.

Uncertainties:

- Linux x86-64 padding was measured in Actions run 39451722783. Clang and the Mojo layout program printed the same offsets as on this Mac (E18).
- The loader's exact C function in OTP's `erl_nif.c` was not recompiled here. The observable contract (symbol `nif_init`, `.so` suffix, version `2.17`, reload error text) was checked from this erts install and from ExUnit.
- Whether a future Mojo release keeps `RegisterPassable` layout identical to clang's is unknown. Re-run both layout programs after every compiler bump.

## Hands-on exercise

```sh
scripts/run-abi-experiments.sh
```

Diff the `diagnostic C` section against the `03 layout` section. Every Mojo offset should appear in the clang listing. `optional_none_or` should be 0. If a Mojo size changes and the C size does not, the NIF is no longer the OTP struct, even if it still compiles.

## Line-by-line walkthrough

`nif_init` in [native/poc.mojo](../native/poc.mojo) writes the constants above in field order:

- `c_int(2)`, `c_int(17)` — major, minor
- `"Elixir.Mojoler.POC"` — module name
- `c_int(1)` — one function
- pointer to a one-element table whose name is `"add"`, arity 2, flags 0
- four `None` values — NULL callbacks
- `"beam.vanilla"`, `c_uint(1)`, `c_size_t(40)`, `"erts-14.0"`

The table and the entry are separate `calloc`s. `calloc` zeros memory before the assignment; the assignment then writes every field.

## Under the hood

The diagnostic program is C on purpose. `offsetof` is how this platform's clang lays the header out, which is the layout the VM was compiled with (the erts in the asdf install was built for this OS). Mojo is then asked to print its own offsets. Agreement is the evidence. A single compiler printing both would not test whether Mojo matches OTP's clang.

The diagnostic binary is not on the `mojo build` command line. `scripts/build-native.sh` takes one input: `native/poc.mojo`.

## Failure modes

- Reordering fields to "look nicer". Offsets move, the VM reads `name` as a pointer made of two ints.
- Updating the minor version in Mojo without updating `min_erts` and the resource size from a new diagnostic run.
- Assuming `.dylib` because the laptop is a Mac. This OTP's loader appends `.so`. The successful path in tests is `priv/native/libpoc.so`.

## Rustler and Zigler

Rustler's `ErlNifEntry` is a `#[repr(C)]` struct kept in sync with OTP by the crate, often with `size_of` assertions. Zigler's `extern struct` relies on Zig matching C layout, and the project re-checks when OTP bumps the minor version. Mojoler's check is the paired printout in `experiments/abi/OBSERVED.txt`. There is no code generator keeping it fresh; a version bump is a manual re-measure.

## Checkpoint

1. Why is `funcs` at offset 24 rather than 20? `num_of_funcs` is a 4-byte int at 16, and the following pointer is 8-byte aligned.
2. What is `sizeof_ErlNifResourceTypeInit` doing in an `add` NIF that has no resources? It is a version tag the VM uses to know how large that struct was when the NIF was built. The measured value is 40.
3. Stretch: add a field to the Mojo struct only, rerun experiment 03, and confirm the size moves while the C size stays 96. Revert the field.
