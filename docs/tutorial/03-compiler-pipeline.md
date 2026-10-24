# Unit 3 — Mojo compiler pipeline

## Objectives

Name the artifacts between a `.mojo` file and the `.so` the BEAM loads, and say which ones were actually inspected.

## Why

"It compiled" does not say whether the callback is a C function or whether `enif_get_long` is a direct call.

## Model

```text
.mojo  ->  mojo build --emit shared-lib  ->  Mach-O or ELF .so
                |
                +-- --emit llvm   (when you ask)  ->  .ll with call @enif_get_long
```

## Theory

`scripts/build-native.sh` invokes `mojo build <file> --emit shared-lib -I native` plus `MOJO_LINK_FLAGS`. The compiler's own runtime is a dependency on Darwin (E11). The LLVM for the Stage 0 NIF contained `call i32 @enif_get_long` (E12). This curriculum does not claim a full picture of MLIR passes. The CLI did not print MLIR for that experiment.

Optimization: a spin loop that only calls `enif_monotonic_time` is a real call, so the compiler cannot delete it as a dead store. The heartbeat measurement (unit 12) is the evidence the loop ran for about 200 ms.

## Lab

```sh
scripts/inspect-abi.sh priv/native/libpoc.so
```

## Expected

`file` reports a shared library for this architecture. `nm` shows `nif_init` as the exported definition (`_nif_init` on Darwin). Undefined symbols include `enif_get_long` and `enif_make_long`.

## Code

`native/poc.mojo` is the whole translation unit for `libpoc.so`. Imports from `mojoler.abi` are compiled into that same library. There is no separate C object.

## Failure

Crashpad's "Failed to initialize Crashpad" comes from the `mojo` driver. The build's exit status is the result that matters. A non-zero status means the `.so` was not published, because the Mix task only renames after exit 0.

## Exercise

Which file is the proof that diagnostic C is not in the link?

## Answer

`priv/native/link-inputs.txt`, written by `scripts/build-native.sh`. `scripts/check-abi.sh` fails if a `.c` path appears there.
