# Unit 4 — ABI and layout

## Objectives

Compare one clang measurement with one Mojo measurement, field by field.

## Why

`RegisterPassable` means the compiler will not secretly insert a pointer. It does not mean the field order matches `erl_nif.h`. The diff does.

## Model

```text
clang offsetof(ErlNifFunc, fptr)  ==  reflect field fptr in Mojo
Optional[Pointer] None            ==  eight zero bytes
thin function                     ==  eight-byte code address
```

## Theory

On both measured LP64 targets, `ErlNifFunc` is 32 bytes and `ErlNifEntry` is 96. `ErlNifBinary` is 40. The C field `__spare__[2]` is `spare_0` and `spare_1` in Mojo. The layout diff keeps `spare_0` (the offsetof of `__spare__`) and drops `spare_1` before comparing, because C has one array field and Mojo has two slots.

Nullable callbacks in the entry are `Optional[Pointer[NoneType, MutUntrackedOrigin]]`. The code address of a thin function is the bits stored in the function value. `Pointer(to=callback)` is the stack slot. `prim.callback_opt` reads those bits.

`enif_open_resource_type`'s generated wrapper takes a generic origin inside the function type, and a concrete dtor does not convert to it. `native/own.mojo` calls the symbol with `external_call` and the concrete dtor type. That is a recorded hole in the wrapper, not a second layout.

## Lab

```sh
scripts/check-abi.sh
```

## Expected

`layout ok` and `dirty flags ok`. A mismatch prints a unified diff and exits 1.

## Code

`tools/abi/print_layout.mojo` uses `std.reflection` for the offsets. The C probe is a heredoc inside `scripts/check-abi.sh`. Neither file is passed to `mojo build` of a NIF.

## Failure

Editing `otp_nif.mojo` by hand makes `--check` fail. Regenerate with `python3 tools/abi/generate.py`. If the header hash changed because OTP moved, the generator's pin file should fail first.

## Exercise

Why is one generated file valid on both Darwin and the recorded Linux runner?

## Answer

E7 and E18 measured the same sizes and offsets. The generator still refuses to label a host probe as a different triple. The Linux *file* was not regenerated on Ubuntu for the later stages; that rerun is PENDING.
