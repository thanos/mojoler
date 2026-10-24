# Unit 12 — Scheduling

## Objectives

Read a heartbeat count, and state what an Elixir timeout does not do.

## Why

A NIF with flags 0 on the only scheduler stops every other process. Dirty CPU exists so a long loop does not do that. It does not make the loop cancellable.

## Model

```text
flags 0        this scheduler, until the function returns
flags 1        dirty CPU scheduler     abi_dirty_cpu()
flags 2        dirty I/O scheduler     abi_dirty_io()
anything else  generator error, not a runtime surprise
```

## Theory

The measurement starts a VM with `+S 1`, so there is a single normal scheduler. A heartbeat process sends every 10 ms. After the mailbox is drained, `burn(200)` runs.

Dirty result from E22: 18 beats, elapsed 200. Normal control: 0 beats, elapsed 200. The control library is not installed in `priv/`. It is built into a temp directory so a product function cannot accidentally use flags 0 for that loop.

`hold/2` copies first, frees the inspect struct, then spins. The borrowed pointer is not live across the wait.

`Task.yield(task, 30)` returned nil. `Task.await` later got `:ok`. The 30 ms stopped the caller. The native function ran on.

`io_ping/0` is on the I/O flag so the constant is executed, not only parsed. It is not a disk job. The name is the scheduler class.

## Lab

```sh
MOJOLER_SKIP_BUILD=1 scripts/measure-heartbeat.sh
mix test test/sched_test.exs
```

## Expected

`heartbeat ok dirty=<positive> normal=0`. The ExUnit test includes the yield.

## Code

`native/sched.mojo` sets the flags from `abi_dirty_cpu()` and `abi_dirty_io()`. `experiments/sched/normal_burn.mojo` hard-codes `c_uint(0)` and is labeled disposable at the top of the file.

## Failure

Declaring `schedule: "sideways"` in the DSL exits 1 before any `.so` is written (`tools/dsl/bad_schedule.json`). Declaring a borrow with `dirty_cpu` exits 1 as well, because the view would have to outlive the callback setup and the generator refuses that shape.

## Exercise

Does `enif_consume_timeslice` run inside `burn/1`?

## Answer

No. The function busy-waits on `enif_monotonic_time` until the requested milliseconds pass. Reporting a timeslice would not be preemption, and this code does not report one.
