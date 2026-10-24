# Unit 5 — Dynamic linking

## Objectives

Explain why the `.so` has undefined `enif_*` symbols and still loads, and why a typo must fail even when the linker is told to ignore undefined symbols.

## Why

Linux `--unresolved-symbols=ignore-all` will happily emit `enif_make_lonq`. The BEAM would then crash on the first call. The import gate exists because the link line cannot see the mistake.

## Model

```text
mojo build  ->  .so with U enif_get_long
dyld/ld.so  ->  binds that symbol into beam.smp at load
check-imports  ->  every U must be on the allowlist
```

## Theory

Darwin needs `-undefined dynamic_lookup` or two-level namespace will not bind NIF symbols to the BEAM (D3). Linux `ld` with `ignore-in-shared-libs` still reported `enif_make_long` from the Mojo archive (run 39365275751). The line that linked is `ignore-all` plus `-z undefs` (D10).

The filename is `.so` on both platforms because `load_nif` appends `.so` (D7). The Mach-O type can still be a dylib.

`tools/abi/functions.txt` is the `enif_*` allowlist. `tools/abi/compiler_imports.txt` is `abort`, `calloc`, `free`, `dyld_stub_binder`, and `enif_monotonic_time` (called via `external_call`, so it is not a generated wrapper). A symbol is added when a built library imports it and the source of that import is known.

## Lab

```sh
scripts/check-abi.sh
scripts/inspect-abi.sh priv/native/libtwice.so
```

## Expected

The check prints `misspelled import rejected` and `imports ok` for each product library. `inspect` shows `nif_init` defined and `enif_get_long` undefined.

## Code

`experiments/abi/negative/bad_import.mojo` calls `enif_make_lonq`. The check builds it in a temp directory and requires `check-imports.sh` to fail.

## Failure

If you need a new `enif_*`, add it to `functions.txt` and regenerate. Adding it only to the Mojo file makes `check-imports.sh` fail the product library. That is the repair: allowlist, regenerate, rebuild.

## Exercise

Why may Darwin list KGEN when Linux `add` must not be required to?

## Answer

The Stage 0 Linux `ldd` did not list it (E19). The test asserts KGEN on Darwin and refutes it on Linux. A later library might differ; it has to be measured, not copied from the Darwin row.
