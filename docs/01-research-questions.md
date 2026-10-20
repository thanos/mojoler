# 01 — Research questions

## Learning objectives

- Separate "Mojo can export a C function" from "the BEAM loaded a NIF".
- Read the minimum passing demonstration as an ExUnit assertion, not a feeling.

## Why this matters

The tempting shortcut is to compile `add`, see a symbol, and declare the ABI solved. The BEAM will still refuse the library if the entry struct is the wrong size, the name string is wrong, or `enif_make_long` was never bound. The questions below are the ones the rest of the docs answer with command output.

## Mental model

```text
question --> experiment --> ledger row --> gate
                |
                +--> unexpected compiler error is itself an answer
```

## Theory

The questions, and where they were closed:

1. Can this Mojo emit a loadable shared library with a C ABI symbol? Yes. Ledger E2 and E3.
2. Can Mojo represent `ErlNifEntry` and `ErlNifFunc` for erts 16.2, including padding? Yes. The sizes and offsets match the diagnostic C program. Ledger E5 and E7.
3. Can it export `nif_init` with default visibility? Yes. `nm -gU` shows a global `T _nif_init`. Ledger E11.
4. Can it call the NIF API the way this OTP actually exposes it? Yes, by leaving `enif_get_long`, `enif_make_long`, and `enif_make_badarg` undefined. Not by calling `enif_get_int64`, and not by inventing the Windows callback table. Ledger E6 and E12.
5. Can it read terms, build a term, and report badarg? Yes. ExUnit covers 42, negatives, non-integers, and the signed 64-bit edges. Ledger E13.
6. Can it be loaded in more than one OS process, and called repeatedly and concurrently? Yes for fresh processes, repeats, and 40 tasks. A second `load_nif` in the same module is rejected by OTP 20+ rules. Ledger E13 and E14.
7. Which Mojo features need `initialize_runtime`? The integer `add` path does not call it and still passes. Calling it twice from another `nif_init` also survived and returned 7. Thread-pool and GPU APIs were not in this stdlib. Ledger E15.

Minimum demonstration, met by `mix test`:

```text
Mojoler.POC.add(20, 22) == 42
```

through the Mojo NIF, with `nm` / `otool` checks in the same suite.

## Hands-on exercise

Run `scripts/test-isolated.sh`. Success is `11 passed` and a process that exits 0. A hang is cut off at 180 seconds because the script wraps Mix in `perl -e 'alarm'`.

Do not treat a green `mojo build` of `experiments/abi/01_export_add/add.mojo` as this exercise. That file has no `nif_init`.

## Line-by-line walkthrough

The Elixir side of the minimum demonstration is the stub in [lib/mojoler/poc.ex](../lib/mojoler/poc.ex):

- `@on_load :load_nif` runs when the module is loaded.
- `Application.app_dir(:mojoler, "priv/native/libpoc")` is the path without a suffix. OTP appends `.so` on this Darwin build, which is why the file is not named `.dylib`.
- `add/2` raises `:nif_not_loaded` only if the native function was not installed. After a successful load, the BEAM replaces that body.

## Under the hood

`load_nif` resolves `nif_init`, checks the major version and `vm_variant`, and then calls through `ErlNifFunc.fptr`. A wrong `name` field fails with a message that mentions the calling module. That happened during development when the test module called `load_nif` directly: the entry said `Elixir.Mojoler.POC` and the caller was `Elixir.Mojoler.POCTest`.

## Failure modes

- Tests fail in `load_nif` before any assertion: the `.so` did not build, the rpath cannot see `libKGENCompilerRTShared.dylib`, or dyld could not bind `enif_get_long`. Run `scripts/inspect-abi.sh`.
- `add` returns a wrong integer: the term width or the overflow check drifted. Re-run the layout experiment before editing the arithmetic.
- Claiming Linux works because the Mac run passed: that claim is out of bounds. This tree has no Linux log.

## Rustler and Zigler

Both projects treat "the shared object loads and an ExUnit test calls it" as the bar, and both generate the entry table. The questions here are the same questions their code generators had to get right. Stage 0 answers them by hand so the failure, if it comes back, is a compiler or ABI fact rather than a generator bug.

## Checkpoint

1. Which experiment is not yet a NIF? `01_export_add`.
2. What string must `ErlNifEntry.name` contain? `Elixir.Mojoler.POC`.
3. Stretch: call `load_nif` from a different module and read the `bad_lib` error. Put the command and the text in the ledger if you keep the experiment.
