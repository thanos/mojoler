# Unit 6 — BEAM internals for NIF authors

## Objectives

Follow one Elixir call into Mojo and back, and name what the VM will not forgive.

## Why

The callback runs on a scheduler thread, with a term environment that dies when the callback returns. Keeping that environment is a use-after-free that looks like a flaky test.

## Model

```text
Elixir process
  -> scheduler
    -> nif_init's function pointer
      -> enif_get_long(env, argv[i])
      -> enif_make_long(env, n)
    -> term on the process heap
```

## Theory

A process has a heap and a mailbox. A NIF with flags 0 runs on the scheduler that entered it, and other work on that scheduler waits. Dirty flags move the call to another pool (unit 12).

`ERL_NIF_TERM` is an integer the width of a pointer. It is not a Mojo pointer, and it is not valid in another environment. `enif_make_copy` into an `enif_alloc_env` environment is how `retain_binary` keeps a term after the process dies.

`ArgumentError` is `enif_make_badarg`. A raised Mojo error is not that. The abort probe kills the VM. Do not use it in `mix test`'s own process.

Reductions are not consumed just because the function is native. `burn/1` does not pretend that `enif_consume_timeslice` preempts it. The function runs until the clock says it is done.

## Lab

```sh
mix test test/poc_test.exs test/term_test.exs
```

## Expected

`add(20, 22)` is 42. `copy_binary` of `<<1, 2, 3>>` is `{:ok, <<1, 2, 3>>, 3}`. A 7-bit bitstring is `{:error, :not_binary}`.

## Code

`native/term.mojo` `copy_binary` inspects, allocates a new buffer with `calloc`, copies bytes, builds a new binary, and `free`s both descriptors. The returned term is the only thing Elixir sees.

## Failure

`bad_lib` with a module name means `ErlNifEntry.name` and the Elixir module disagree, or `load_nif` ran in the wrong module. `nif_not_loaded` means the stub ran because `@on_load` did not succeed.

## Exercise

Why does a second `load_nif` of `Mojoler.POC` fail even though `reload` in the entry is null?

## Answer

OTP rejects it before the callback (E14). The error is `{:reload, ...}`.
