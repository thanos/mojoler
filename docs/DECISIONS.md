# Decisions

## D1 — Pin this Mac, OTP 28.3.1, Elixir 1.20.2, Mojo 1.1.0

Linux was not available when this pin was chosen. The newest installed OTP/Elixir pair was already 28.3.1 and 1.20.2. Stable `mojo==1.1.0` emitted `--emit shared-lib`, so nightly was not used. Consequences: every constant in `nif_init` is for NIF 2.17. Linux x86-64 later matched those sizes (E18). Other OTP minors stay untested.

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

## D10 — Linux CI uses `--unresolved-symbols=ignore-all`

`.github/workflows/linux.yml` runs the CPU NIF on `ubuntu-24.04`. Darwin keeps `-undefined dynamic_lookup`. Linux first used `--unresolved-symbols=ignore-in-shared-libs`. Actions run [39365275751](https://github.com/thanos/mojoler/actions/runs/39365275751) linked with `/usr/bin/ld` and failed: `undefined reference to enif_make_long`, because that flag still reports undefined symbols from the Mojo archive. The Linux line is `--unresolved-symbols=ignore-all` plus `-z undefs`. [Run 39451722783](https://github.com/thanos/mojoler/actions/runs/39451722783) is the green log (E18, E19). The workflow does not rent a GPU and does not change the macOS PASS.

## D11 — Generate the ABI, and do not free the entry

`tools/abi/generate.py` reads clang's AST and a layout probe. The probe is not a `mojo build` input. `nif_init` still `calloc`s the entry and the function table. OTP keeps that pointer, and a second `load_nif` is rejected, so those two blocks are bounded by one load per module per OS process. `Mojoler.Own` frees its private type box in `unload` with `free`, the pair of `calloc`. Upgrade returns 1. That callback was not invoked by a test.

## D12 — Do not bundle the Mojo runtime

The Darwin `.so` records an rpath into the venv that built it. Redistribution of `libKGENCompilerRTShared` was not established, so a release prerequisite is a Mojo install that satisfies that rpath. CPU apps do not install MAX. The copied consumer release on this Mac printed 42 with the original venv still present.

## D13 — Declarations are Elixir data

`tools/dsl/decls.json` is the author-facing model. `tools/dsl/generate.py` emits the wrapper, `nif_init`, and the Elixir stub. User functions stay in `native/examples/`. A schedule other than `normal`, `dirty_cpu`, or `dirty_io` fails the generator. A borrow combined with a dirty schedule fails it too. The generator does not eval the JSON as code.

## D9 — Checked overflow is `ArgumentError`

Elixir integers are unbounded. The NIF's range is signed 64-bit. Sums outside that range, and terms `enif_get_long` rejects, become badarg. They do not wrap. The comparison is written so the check itself stays inside `c_long`.
