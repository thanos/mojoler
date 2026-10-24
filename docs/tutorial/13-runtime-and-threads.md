# Unit 13 — Mojo runtime and threads

## Objectives

Separate "the runtime `.so` is on the link line" from "we measured the thread pool".

## Why

Stage 0 called `initialize_runtime` twice in a side experiment and got 7 (E15). That does not describe shutdown, oversubscription, or a worker calling `enif_*` on the caller's env.

## Model

```text
Darwin otool -L     libKGENCompilerRTShared, sometimes libAsyncRTMojoBindings
Linux ldd of add    libc and the dynamic linker only (E19)
initialize_runtime  required before the MAX GPU callback, not before add/2
```

## Theory

`add/2` does not call `initialize_runtime` (D6). The GPU batch does, once per call, because the MAX context needs it. Two concurrent batch calls both returned 110 (E25). That is two successful calls, not a study of the driver's lock. Do not describe it as a proof that arbitrary Mojo threads may share an `ErlNifEnv`.

No product callback starts a Mojo thread and then uses the caller's `env`. `hold` and `burn` finish before they return. There is no queue, so there is no queue-rejection test. The retained-env rule is still enforced for the path that keeps a term: `retain_binary` copies before it returns the handle, and `hold` copies before it spins.

The abort probe is the shutdown-adjacent fact: `abort` kills that OS process. It does not unwind into Elixir.

## Lab

```sh
scripts/inspect-abi.sh priv/native/libpoc.so
```

On Linux, after a build there, `ldd priv/native/libpoc.so` is the comparison. Do not paste the Darwin list into a Linux claim.

## Expected

Darwin shows KGEN. The import check still passes, because KGEN is a dependency, not an undefined `enif_*` typo.

## Code

`experiments/gpu/batch_nif.mojo` calls `initialize_runtime()` at the start of `batch`. `native/poc.mojo` does not.

## Failure

Loading the GPU `.so` without MAX installed fails at `dlopen` or at compile time. `scripts/gpu-batch.sh` exits 2 with `NOT RUN`. A CPU `mix test` never builds that file.

## Exercise

Why is the Linux absence of KGEN in E19 not a license to delete the Darwin rpath?

## Answer

They are different link results. The Darwin library needs the rpath that `otool` printed. The release notes in `docs/runtime.md` keep the Mojo install as a prerequisite instead of copying the dylib.
