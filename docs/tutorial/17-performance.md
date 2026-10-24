# Unit 17 — Performance engineering

## Objectives

Split one demo's numbers into boundary, copy, and kernel, and refuse a speed claim for `add/2`.

## Why

E16 already showed a loop of `add/2` slower than Elixir `+`, with the loop inside both measurements. A library that advertises that call as a win is misreading its own ledger.

## Model

```text
cold compile     mojo build, only when the fingerprint changes
warm boundary    one add, warm_add_us in the demo (a single sample)
copy cost        the integer in {:ok, binary, nbytes}
kernel           dirty_burn_us, about the requested 50 ms
```

## Theory

`scripts/demo-cpu.sh` prints those lines (E24). `warm_add_us 4` is one call on one machine. It is not a p50. There is no crossover chart, because a single sample is not a distribution, and the Stage 0 loop already lost to Elixir `+`.

`copy_binary` reports the payload bytes it copied. Metadata (`ErlNifBinary` via `calloc`) is a separate allocation and is freed before return. The byte count is the payload, not the descriptor.

The batch GPU sum is a different kernel. Its oracle is 110, checked before anyone talks about device time. This demo does not subtract host transfer from compute. Those phases are not separately timed.

## Lab

```sh
scripts/demo-cpu.sh
```

## Expected

`oracle 42`, a copy count equal to `byte_size`, a borrow flag of 1, and a dirty burn on the order of 50 ms. The warm number will move. Do not check it into a threshold.

## Code

`scripts/demo-cpu.sh` is Elixir via `mix run --no-start`. The functions are the public API, so the demo fails if a stub is still `nif_not_loaded`.

## Failure

Treating `warm_add_us` as a regression gate. The workflow does not. Functional tests are the gate. A noisy microsecond is not.

## Exercise

Why is `add/2` the wrong function to speed up?

## Answer

The work is two `enif_get_long` calls and an add. Elixir `+` on small integers is already that, without a NIF crossing. E16 measured the Elixir loop as cheaper. The interesting costs are copies, long CPU, and the GPU batch, each with an oracle.
