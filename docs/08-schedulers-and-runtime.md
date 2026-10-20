# 08 — Schedulers and the Mojo runtime

## Learning objectives

- Decide whether `add` belongs on a normal scheduler.
- Say what `initialize_runtime` did and did not prove.
- Read the overhead numbers as a loop-including comparison, not as a pure NIF cost.

## Why this matters

Mojo's selling point is native code and a runtime with a thread pool. A BEAM node already has schedulers. Loading another thread pool into every NIF call can oversubscribe the machine and can run code on threads the VM does not know about. The integer proof avoids that pool on purpose.

## Mental model

```text
normal scheduler thread
  |
  +-- NIF add (flags = 0) -- enif_get_long, add, enif_make_long
  |
  +-- other Erlang processes wait while this NIF runs

dirty CPU scheduler          only if flags include 1
dirty IO scheduler           only if flags include 2

Mojo runtime threads         only if initialize_runtime / parallelize ran
```

## Theory

A normal NIF should do a bounded amount of work. It does not preempt. Reductions are how the VM accounts for Erlang work; a NIF that cares calls `enif_consume_timeslice`. `add` does not. The body is three external calls and a checked add.

Dirty flags are the `unsigned` at offset 24 of `ErlNifFunc`. Values 1 and 2 come from `erl_drv_nif.h` via `erl_nif.h`. They are not inferred from Mojo annotations because there are no Mojo annotations in this project. Leaving the field 0 keeps `add` on the normal scheduler.

A GPU launch and a GPU wait are different costs. A launch that only queues work can be short. A wait that spins or sleeps holds the scheduler for the whole wait. This repository never launched a GPU kernel. The compiler rejected `std.gpu` and pointed at the `max` package. No claim is made about GPU code inside a NIF.

`initialize_runtime` prepares the process-global Mojo runtime. The manual says it is idempotent and that one call covers the process. The experiment in `experiments/abi/05_runtime/rtnif.mojo` calls it twice inside `nif_init` and then returns the term 7. The fresh BEAM printed `runtime ping 7`. So two calls during init did not crash, and a later NIF call on that library worked. The add library does not call it, and `mix test` still passes. Idempotence under concurrent scheduler threads was not tested. Thread-pool work was not tested.

Mojo traps and memory faults are not catchable as Elixir exceptions. The IR contains `llvm.trap`. If that runs inside the NIF, the OS process dies. `scripts/test-isolated.sh` puts `mix test` under an alarm so a dead or stuck VM does not hang the shell. It does not turn a trap into `ArgumentError`.

## Hands-on exercise

Rebuild and load the runtime experiment:

```sh
.venv/bin/mojo build experiments/abi/05_runtime/rtnif.mojo \
  --emit shared-lib -o /tmp/librt.so \
  -Xlinker -undefined -Xlinker dynamic_lookup
```

Then `load_nif` the path without the suffix from a new `elixir -e` process, as in chapter 01's module shape, and call `ping`. The recorded result is the integer 7. A crashpad line on stderr can appear during `mojo build` and is separate from the BEAM result.

Do not point this experiment at `priv/native/libpoc.so`. That file is the add NIF and does not export `ping`.

## Line-by-line walkthrough

The benchmark that was actually run, via `mix run --no-start -e`:

- warmup 10_000 calls of `Mojoler.POC.add(20, 22)` and 10_000 evaluations of `20 + 22`
- 5 trials of 100_000 iterations each
- `:timer.tc` around the whole `for` comprehension, so the loop is inside the number

Recorded microseconds, NIF: `38188, 37250, 36213, 34686, 36222`. Elixir `+`: `24655, 24961, 23204, 23876, 23806`. Divided by 100_000 and converted to nanoseconds, that is about 347–382 ns per NIF iteration and about 232–250 ns per Elixir iteration, loop included.

The Elixir addition of two small integers is a VM instruction. The NIF pays for entering native code and two `enif_*` calls to do the same arithmetic. The NIF is the slower one. Speed is not the result of Stage 0.

## Under the hood

`libKGENCompilerRTShared.dylib` is mapped when the `.so` loads, even though `add` never calls `initialize_runtime`. Its presence means the process is running vendor runtime code at load time. What that code does on `dlopen` was not traced instruction by instruction. The observable fact is that `load_nif` returns `:ok` and later calls work.

Oversubscription: if a future NIF called `parallelize` across all cores from a normal scheduler, it would compete with the other BEAM schedulers. The dirty CPU pool is the VM's tool for "this native work may use more CPU". Combining it with a Mojo thread pool would still need a measured cap. Not done here.

## Failure modes

- Interpreting the nanosecond figures as the cost of `nif_init` or as a pure call boundary. Both measurements include the Elixir `for` loop, and they were taken in one OS process with no statistical model beyond five samples.
- Calling `initialize_runtime` on every `add` "to be safe". The passing NIF shows it is not required for this body, and doing it per call would be extra shared-state traffic that was not measured.
- Expecting a Mojo panic to show up as `{:error, ...}` in Elixir. It will not.

## Rustler and Zigler

Rustler documents dirty schedulers as an annotation because Rust NIFs often do real work, and it treats panics as fatal. Zig has no separate runtime thread pool in the usual Zigler NIF, so the oversubscription problem is mostly "did you start threads yourself". Mojo is closer to a runtime language than Zig is. The honest Stage 0 stance is: the runtime dylib is loaded, the thread pool is not started by `add`, and starting it inside the BEAM was only tested as "call `initialize_runtime` twice, then return 7".

## Checkpoint

1. What flag value keeps a NIF on a normal scheduler? 0.
2. Did `add` call `initialize_runtime`? No. Did a different NIF call it twice and survive? Yes.
3. Stretch: repeat the five trials in a freshly booted VM three times and keep the spread. Do not drop the Elixir baseline.
