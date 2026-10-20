# Decisions

## D1 — Pin this Mac, OTP 28.3.1, Elixir 1.20.2, Mojo 1.1.0

Linux was not available. The newest installed OTP/Elixir pair was already 28.3.1 and 1.20.2. Stable `mojo==1.1.0` emitted `--emit shared-lib`, so nightly was not used. Consequences: every constant in `nif_init` is for NIF 2.17 on LP64 Darwin. Other platforms stay untested.

## D2 — Call `enif_get_long` and `enif_make_long`

`SIZEOF_LONG` is 8, so `enif_get_int64` and `enif_make_int64` are macros. `beam.smp` exports the long symbols. Calling the macro name would not link. The Windows function-pointer table is a different ABI and is not filled in on Unix.

## D3 — Link with `-undefined dynamic_lookup`

`mojo build` accepts `-Xlinker`. Darwin will not bind undefined NIF symbols to the BEAM without flat lookup. `OwnedDLHandle()` on the current process was the backup and was not required once this link succeeded.

## D4 — `calloc` the entry and the function table

Mojo 1.1.0 rejects global `var`. A stack `ErlNifEntry` would dangle after `nif_init` returns. `calloc` is libc, called from Mojo, and it is not a C source file in the link. Unload does not free the blocks. That leak is accepted for Stage 0 and called out in chapter 07.

## D5 — NULL callbacks are `Optional[Pointer]`, not optional functions

`Optional` of a thin function measured 16 bytes and would break the entry layout. `Optional[Pointer[NoneType, MutUntrackedOrigin]]` measured 8 bytes, and None measured as eight zero bytes, which is C NULL.

## D6 — Do not call `initialize_runtime` in `add`

The integer path passed without it. A separate NIF called it twice and then returned 7, so the function can run inside `nif_init`. Leaving it out of `add` keeps the Mojo thread pool from being part of the success claim.

## D7 — Ship `libpoc.so`, not `libpoc.dylib`

This OTP's `load_nif` appends `.so` on Darwin. The Mach-O type can still be a dylib; the filename is what the loader concatenates.

## D8 — Diagnostic C never joins the NIF link

`experiments/abi/diagnostic/layout.c` exists to ask clang for `offsetof`. `scripts/build-native.sh` compiles only `native/poc.mojo`. The feasibility verdict does not treat that C file as a shim.

## D10 — Linux CI uses a different link line, and it is not yet evidence

`.github/workflows/linux.yml` runs the CPU NIF on `ubuntu-24.04`. Darwin keeps `-undefined dynamic_lookup`. Linux first used `--unresolved-symbols=ignore-in-shared-libs`. Actions run [39365275751](https://github.com/thanos/mojoler/actions/runs/39365275751) linked with `/usr/bin/ld` and failed: `undefined reference to enif_make_long`, because that flag still reports undefined symbols from the Mojo archive. The Linux line is now `--unresolved-symbols=ignore-all` plus `-z undefs`. A later green run is what verifies it. The workflow does not rent a GPU and does not change the macOS PASS.

## D9 — Checked overflow is `ArgumentError`

Elixir integers are unbounded. The NIF's range is signed 64-bit. Sums outside that range, and terms `enif_get_long` rejects, become badarg. They do not wrap. The comparison is written so the check itself stays inside `c_long`.
