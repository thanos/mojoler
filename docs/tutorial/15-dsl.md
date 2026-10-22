# Unit 15 — DSL and code generation

## Objectives

Follow one JSON object through a Mojo wrapper, a user function, and an Elixir stub.

## Why

Authors should not restate `ErlNifEntry` for every function. They also should not hide the wrapper. Generated source is committed and diffed so a review can read it.

## Model

```text
tools/dsl/decls.json
  -> tools/dsl/generate.py
    -> native/generated/<name>.mojo     wrapper, nif_init
    -> lib/mojoler/dsl/<name>.ex        stub and load_nif
native/examples/<name>_user.mojo        the computation, no entry struct
```

## Theory

The JSON is data. The generator does not `eval` it. Schedules are `normal`, `dirty_cpu`, `dirty_io`. Ownership `borrow` with a dirty schedule is rejected because the view would cross the callback boundary.

`Arith.add` decodes two longs, calls `checked_add`, and encodes `{:ok, n}` or `{:error, :overflow}`. `Bytes.shift` copies, runs `shift_byte` per byte, and returns the byte count. `Bytes.borrow_len` inspects and returns the size, or `{:error, :not_binary}`. `Box.open` / `bump` allocate a resource and call `step`.

Two modules, `Arith` and `Bytes`, load in one test. Each `.so` has its own `nif_init`. The entry name strings differ.

## Lab

```sh
python3 tools/dsl/generate.py --check
mix test test/dsl_test.exs
python3 tools/dsl/generate.py --decls tools/dsl/bad_schedule.json ; echo exit:$?
```

## Expected

`--check` prints `dsl mojo: matches`. The tests pass. The bad file prints `schedule sideways` and the exit status is 1.

## Code

Read `native/generated/arith.mojo` next to `native/examples/arith_user.mojo`. The user file returns `AddResult`. The wrapper does the `enif_*` calls.

## Failure

A hand edit of `native/generated/arith.mojo` fails `--check`. Either change the generator and regenerate, or change the user file, which is not generated.

## Exercise

Where is the dirty-CPU flag for a generated function?

## Answer

In the JSON `schedule` field. The generator writes `c_uint(0)`, `abi_dirty_cpu()`, or `abi_dirty_io()` into `ErlNifFunc`. The three examples use `normal`, so the flag is `c_uint(0)`. `Mojoler.Sched` sets the dirty flags itself because it is not a JSON entry.
