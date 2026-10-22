# Unit 16 — Debugging native failures

## Objectives

Classify badarg, a load error, and a trap, and run the trap in another process.

## Why

One of those kills the VM. Debugging it inside `mix test` takes the suite with it.

## Model

```text
ArgumentError          enif_make_badarg, process survives
{:error, reason}       a term, process survives
bad_lib / reload       load_nif failed, stubs then raise
abort                  child OS process dies, parent records the status
```

## Theory

`scripts/probe-abort.sh` builds `experiments/probes/abort.mojo` into a temp directory, starts `elixir`, and requires a non-zero status. The product libraries do not call `abort` on a caller's behalf. `must_alloc` does, if `calloc` fails while building the entry. That path is not injected in the suite.

`scripts/inspect-abi.sh` is the symbol step: defined `nif_init`, undefined `enif_*`, `otool -L` or `ldd`. `mojo build --emit llvm` is the IR step when the callback is wrong but the load succeeded. LLDB and GDB were not used for the rows in the ledger. The curriculum does not claim a sanitizer run.

A minimized reproducer is a new `.mojo` under `experiments/` that is not added to `scripts/build-native.sh`. The normal-scheduler burn and the abort probe are the pattern.

## Lab

```sh
scripts/probe-abort.sh
```

## Expected

`probe_exit` with a non-zero status, then `probe ok`. The shell's exit status is 0 because the probe did its job. A zero from the child is a failed probe.

## Code

`experiments/probes/abort.mojo` exports `boom/0` and calls `external_call["abort", NoneType]()`.

## Failure

If the child prints `42` and exits 0, the NIF did not run. Check the module name `Elixir.Mojoler.AbortProbe` against the entry string, and check that `load_nif` is called from that module.

## Exercise

Which failure is `{:error, {:reload, _}}`?

## Answer

A load error from OTP, not a Mojo trap. The library was already loaded in that VM (E14).
