# Direct Mojo proof

This file records how the loaded NIF was shown to be the Mojo build of [native/poc.mojo](../native/poc.mojo), rather than a C file compiled beside it.

## Build command

`scripts/build-native.sh` runs only:

```text
.venv/bin/mojo build native/poc.mojo \
  --emit shared-lib \
  -o priv/native/libpoc.so \
  -Xlinker -undefined \
  -Xlinker dynamic_lookup
```

The script does not pass a `.c`, `.cc`, or `.o` file. `experiments/abi/diagnostic/layout.c` is compiled only by `scripts/run-abi-experiments.sh`, and that binary is `experiments/abi/diagnostic/layout`, not `priv/native/libpoc.so`.

## Exported and imported symbols

`scripts/inspect-abi.sh` on the built library:

```text
0000000000000754 T _nif_init
```

Undefined symbols:

```text
_abort
_calloc
_enif_get_long
_enif_make_badarg
_enif_make_long
dyld_stub_binder
```

`nm` without `-gU` also shows one local text symbol, the mangled `add` callback (`t _poc::add(...)`). The BEAM does not `dlsym` that name. `nif_init` stores the thin function pointer in the `ErlNifFunc` it returns.

There is no undefined `enif_get_int64`. On this OTP that name is a preprocessor macro.

## Linked images

`otool -L`:

```text
priv/native/libpoc.so
@rpath/libKGENCompilerRTShared.dylib
/usr/lib/libSystem.B.dylib
```

The rpath is `.venv/lib/python3.12/site-packages/modular/lib`. `libKGENCompilerRTShared.dylib` is the Mojo compiler runtime that `mojo build` linked. It is not a NIF shim written for this project. `libSystem` supplies `calloc` and `abort`.

## IR check

`mojo build native/poc.mojo --emit llvm` contains direct declarations:

```text
declare i64 @enif_make_badarg(ptr)
declare i32 @enif_get_long(ptr, i64, ptr)
declare i64 @enif_make_long(ptr, i64)
declare i64 @calloc(i64, i64)
declare void @abort()
```

The same file also declares `write`, `dup`, `fdopen`, `fflush`, `fclose`, and `KGEN_CompilerRT_AlignedFree`. Those are inserted by the compiler. They are part of the honest dependency list. They are not a second source file that implements `add`.

## Load check

ExUnit loads this `.so` through `:erlang.load_nif/2` and asserts `Mojoler.POC.add(20, 22) == 42`, plus the `nm` expectations above. A separate OS process does the same load and exits 0.
