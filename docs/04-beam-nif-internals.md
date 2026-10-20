# 04 — BEAM NIF internals

## Learning objectives

- Trace one Elixir call into a native function and back to a term.
- Explain why a NIF crash takes down the scheduler, and often the VM.
- Read dirty-scheduler flags as data in `ErlNifFunc`, not as a Mojo feature.

## Why this matters

`add/2` is a short function, but it runs on a BEAM scheduler thread with the rest of the VM's memory mapped in. The calling convention in chapter 03 is only safe because of the lifetime rules in this chapter: `env` and `argv` die when the native function returns, and a bad term is a return value, not a raised Mojo error.

## Mental model

```text
Elixir Mojoler.POC.add(20, 22)
        |
        v
BEAM stub for Elixir.Mojoler.POC:add/2
        |
        v
erlang:load_nif  (already done at module load)
        |
        v
dlsym nif_init --> ErlNifEntry
        |
        v
ErlNifFunc { "add", 2, &callback, flags=0 }
        |
        v
callback(env, 2, argv) --> enif_get_long / enif_make_long
        |
        v
ERL_NIF_TERM returned in x0, boxed back into an Elixir integer
```

## Theory

Schedulers run Erlang processes. A NIF runs on the scheduler that called it, and it does not bump reductions unless it calls `enif_consume_timeslice`. A long NIF starves every other process on that scheduler. Dirty CPU and dirty IO schedulers exist so a NIF can declare, in `ErlNifFunc.flags`, that it should run off the normal scheduler. The installed header maps those flags to `ERL_DIRTY_JOB_CPU_BOUND` (1) and `ERL_DIRTY_JOB_IO_BOUND` (2). `add` sets flags to 0. It is a few arithmetic instructions and three external calls. That is the case dirty flags are for avoiding, not for using.

`ErlNifEnv` is opaque. It is the VM's permission slip for allocating terms and the bound on how long those terms live. Terms created in the call's env are valid until the native function returns, unless the API says otherwise. This NIF does not keep them at all. It reads two terms, writes two C longs onto its own stack, and returns one new term.

`ERL_NIF_TERM` is an unsigned integer the same width as a pointer (`ErlNifUInt`). On this LP64 Mac that is 8 bytes. It is not a pointer to an Elixir object that Mojo can dereference. The bits are a tagged value or an immediate. Only `enif_*` knows which.

Terms, binaries, and resources are different:

- A small integer term is copied by value through `enif_get_long`.
- A binary may point at VM memory that is only valid for the call, or until a resource releases it. This NIF does not touch binaries.
- A resource is a VM-tracked allocation with a destructor. `ErlNifResourceTypeInit` is 40 bytes here. The entry records that size so the VM knows which generation of the resource struct the NIF was compiled against. This NIF does not create a resource type. It still has to store `40` in `sizeof_ErlNifResourceTypeInit` or the VM's version check is looking at the wrong field.

Load, reload, upgrade, and unload are optional callbacks. NULL means "do nothing". OTP 20 and later refuses to reload a NIF that is already loaded; the ExUnit test observes that error from a second `load_nif`. Upgrade and unload were not invoked.

`enif_make_badarg` returns a special term. The VM turns it into `ArgumentError` at the Elixir boundary. It is not a C++ exception and not a Mojo `raise`. A Mojo `raise` or `llvm.trap` does not become `ArgumentError`. The IR of `poc.mojo` contains `llvm.trap`, which aborts the thread. In a NIF that means the VM process dies.

Blocking in a normal NIF blocks the scheduler. `add` does not block. A future GPU launch that waited for the device on a normal scheduler would stall the VM even if the launch itself were asynchronous. That combination was not tested.

## Hands-on exercise

Load a node and call the function, then ask OTP for the NIF version:

```sh
mix run --no-start -e 'IO.inspect(Mojoler.POC.add(20, 22)); IO.inspect(:erlang.system_info(:nif_version))'
```

The first value should be the integer 42. The second should be a charlist whose characters are the NIF major and minor, `2.17` on this OTP. The inspect form prints quotes and a trailing blank the way Elixir prints charlists.

## Line-by-line walkthrough

[lib/mojoler/poc.ex](../lib/mojoler/poc.ex) `load_nif/0`:

- `Application.app_dir/2` returns the application priv path as a string.
- `String.to_charlist/1` matches the historical `load_nif` argument. OTP 28 accepted that charlist in the tests.
- The path has no `.so`. The emulator appends it. Naming the Mojo output `libpoc.so` is what makes that append succeed on Darwin, where developers often expect `.dylib`.
- Returning `:ok` from `@on_load` marks the module usable. Returning anything else prevents the module from loading, which is why a missing library fails the whole test run at startup.

`reload/0` exists only so the test can call `load_nif` again from the same module. Calling it from the test module produced `bad_lib` because the entry name did not match the caller.

## Under the hood

The VM compares `ErlNifEntry.major` with the range it can load (`ERL_NIF_MIN_REQUIRED_MAJOR_VERSION_ON_LOAD` is 2) and compares `vm_variant` with `"beam.vanilla"`. `min_erts` is `"erts-14.0"`, copied from `ERL_NIF_MIN_ERTS_VERSION` in the header. Those strings are compile-time literals in the Mojo binary, not read back from the header at runtime. If you upgrade OTP and the variant string changes, the old literal will fail the load. Re-run the diagnostic program and update the literals together.

Dirty flags live in the fourth field of `ErlNifFunc`, at offset 24, width 4, with 4 bytes of tail padding so the struct stays 32 bytes. Leaving that field 0 is an explicit choice.

## Failure modes

- Returning a term built in a previous call's `env`. Use-after-free inside the VM, often a later crash rather than a clean error.
- Storing `argv` in the calloc'd entry. Same class of bug.
- Raising from Mojo instead of `enif_make_badarg`. The test expectation is `ArgumentError`. A trap fails the whole OS process and `scripts/test-isolated.sh` will report a non-zero status or the alarm.
- Setting a dirty flag "just in case" without measuring. It changes which scheduler runs the NIF and is part of the ABI the VM reads. `add` does not set it.

## Rustler and Zigler

Rustler inserts dirty-job flags through annotations (`:dirty_cpu`, `:dirty_io`) that become the same integer flags. Zigler does the same in the generated struct. Both also treat a panic as fatal to the VM and use the NIF badarg term for ordinary argument errors. Mojoler follows that split: `ArgumentError` for bad terms and overflow, process death for a compiler trap.

## Checkpoint

1. What does `enif_make_badarg` return? A term the VM turns into `ArgumentError`, not a Mojo error.
2. Why is `add` not marked dirty? It does not block and it does not run long enough to need another scheduler. The flag is data the VM reads; it is not implied by the language.
3. Stretch: time a NIF that sleeps, with flags 0 and with flag 1, in a VM that is also running a tight Elixir process. Do not add the sleep to `poc.mojo`; keep it in a separate experiment.
