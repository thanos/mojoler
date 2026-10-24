# Unit 1 — From Stage 0 to a library

## Objectives

Reproduce `add(20, 22) == 42`. Separate a row in the evidence ledger from a hope about the next machine.

## Why

Stage 0 is a single function. The later stages are a library only if that function still passes and new claims have their own rows.

## Model

```text
ledger row  ->  a command that was run
stage file  ->  what that command is allowed to mean
PENDING     ->  the workflow exists and this commit has not produced the log
```

## Theory

`Mojoler.POC.add/2` is still the contract: signed 64-bit addition, `ArgumentError` on overflow and on a term `enif_get_long` rejects. `experiments/stage0/poc_direct.mojo` is the file from before the structs moved into the generated ABI. The live `native/poc.mojo` imports that ABI. Both have to agree on 42.

E18 and E19 are the Linux CPU proof for that function at commit `e6728ea`. They are not a proof of the Mix compiler or the GPU batch.

## Lab

```sh
scripts/doctor.sh
mix test test/poc_test.exs
```

## Expected

Doctor prints the pinned OTP, Elixir, and Mojo, then `doctor: ready`. ExUnit reports the POC tests passed, including a fresh OS process.

## Code

`lib/mojoler/poc.ex` calls `:erlang.load_nif` in `Mojoler.POC`, not in a helper. OTP checks the calling module against `ErlNifEntry.name`. A helper that calls `load_nif` itself loads as `Elixir.Mojoler.Nif` and the VM rejects the library.

## Failure

If doctor stops, the rest of the curriculum will not load. If `add` raises `UndefinedFunctionError`, `@on_load` failed. Read the warning above the crash. The usual cause is a module-name mismatch or a missing `.so`.

## Exercise

Find the ledger row that says Linux `ldd` did not list `libKGENCompilerRTShared`.

## Answer

E19. The red run before it printed `libc.so.6` and the dynamic linker only. Darwin still lists KGEN (E11).
