# Unit 14 — Mix integration

## Objectives

Build from `mix test`, see a no-op second compile, and load the NIF from an app that does not mention `mojo`.

## Why

A shell command in `test/test_helper.exs` was enough for Stage 0 and invisible to `mix compile` in another project. The compiler task is the path a dependency actually runs.

## Model

```text
mix compile
  -> Elixir compiler
  -> Compile.Mojoler
       fingerprint match and .so files exist -> {:noop, []}
       else build into staging, rename, write FINGERPRINT
```

## Theory

The compiler is listed after Elixir (`Mix.compilers() ++ [:mojoler]`) so the task module is compiled before it runs. `MOJOLER_OUT` points at `priv/native/staging`. `File.rename` replaces the destination on the same filesystem. The fingerprint file is written after the rename. A failed build deletes staging and leaves the old `.so`.

If this VM has already marked a library loaded (`Mojoler.Nif.mark!/1` from the module that called `load_nif`) and the fingerprint changed, the task errors instead of renaming over a mapped file.

`examples/consumer` depends on `{:mojoler, path: "../.."}`. `examples/umbrella/apps/child` uses the same path from four directories down. Both call `Mojoler.POC.add/2`. Neither passes `-Xlinker`.

## Lab

```sh
mix compile.mojoler
cd examples/consumer && mix test
```

## Expected

The second compiler invocation is a no-op when nothing changed (`test/build_test.exs` asserts `{:noop, []}`). The consumer test passes.

## Code

`lib/mix/tasks/compile/mojoler.ex` and `lib/mojoler/build.ex`. `decide/3` is the table: match and outputs -> `:noop`; loaded and stale -> `:loaded`; else `:build`.

## Failure

A stale `.so` after a Mojo edit: the fingerprint includes the `.mojo` bytes, so the next `mix compile` rebuilds. If you overwrite the `.so` while a VM has it mapped, the next call can crash. Restart the VM. The compiler's error is the reminder.

## Exercise

What does `mix clean` in the consumer prove?

## Answer

E23 ran `mix test`, then `mix clean`, then `mix test` again. The second run passed, so the dependency compiler ran again and produced a loadable library. It does not prove a Linux release.
