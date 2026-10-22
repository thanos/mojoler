# Mojoler tutorial

Start with the [quickstart](quickstart.md) if you want a running `add/2`. How Mojo and the BEAM own values is [ownership.md](ownership.md). The stage verdicts are in [stages/report.md](stages/report.md). The API is [API.md](API.md). Packaging limits are [runtime.md](runtime.md). The compatibility table is [compatibility.md](compatibility.md).

This file is also the Stage 0 path: a Mojo shared library that the BEAM loads as the NIF `Elixir.Mojoler.POC.add/2`. Chapters 00–09 below are that record. Units 1–20 are the library curriculum. Where a Stage 0 sentence is now too narrow, the chapter says so at the top and points at the later measurement.

Read [GLOSSARY.md](GLOSSARY.md) when a word is doing more work than it looks like. The command logs live in [evidence-ledger.md](evidence-ledger.md). The verdict is [09-feasibility-report.md](09-feasibility-report.md). How we know the binary is Mojo is [direct_mojo_proof.md](direct_mojo_proof.md).

Each numbered chapter has the same ten sections: objectives, why it matters, a mental model, theory, a hands-on exercise, a walkthrough, the ABI or compiler detail, failure modes, a Rustler/Zigler note, and a checkpoint. Exercises describe the shape of the output. The ledger is where the actual text from this machine is quoted.

## Chapters

1. [00 — Environment and sources](00-environment-and-sources.md). What was installed, and why `enif_get_int64` is a macro here.
2. [01 — Research questions](01-research-questions.md). The bar for calling the experiment a NIF.
3. [02 — Mojo language and compiler](02-mojo-language-and-compiler.md). `def`, `abi("C")`, and the LLVM add.
4. [03 — FFI and the C ABI](03-mojo-ffi-and-abi.md). Thin function pointers versus a pointer to a stack slot.
5. [04 — BEAM NIF internals](04-beam-nif-internals.md). Schedulers, terms, badarg, and why a trap kills the VM.
6. [05 — OTP ABI map](05-otp-abi-map.md). The measured 32-byte and 96-byte structs.
7. [06 — Mojo meets that ABI](06-mojo-meets-otp-abi.md). The eight experiments and the `calloc` decision.
8. [07 — Memory and lifetime](07-memory-and-lifetime.md). What is borrowed, what is leaked, what was not attempted.
9. [08 — Schedulers and runtime](08-schedulers-and-runtime.md). Dirty flags, `initialize_runtime`, and the overhead samples.
10. [09 — Feasibility](09-feasibility-report.md). PASS for `add/2` on this Mac and on Linux x86-64. One Apple GPU call also returned 42.

## Units

Each unit has objectives, a model, a lab command, a failure, and a checkpoint answer.

1. [From Stage 0 to a library](tutorial/01-from-stage-0.md)
2. [Mojo language essentials](tutorial/02-mojo-essentials.md)
3. [Mojo compiler pipeline](tutorial/03-compiler-pipeline.md)
4. [ABI and layout](tutorial/04-abi-and-layout.md)
5. [Dynamic linking](tutorial/05-dynamic-linking.md)
6. [BEAM internals for NIF authors](tutorial/06-beam-internals.md)
7. [OTP ABI automation](tutorial/07-otp-abi-automation.md)
8. [Safe conversion design](tutorial/08-safe-conversion.md)
9. [Memory across runtimes](tutorial/09-memory-across-runtimes.md)
10. [Resources and finalizers](tutorial/10-resources-and-finalizers.md)
11. [Binary ownership](tutorial/11-binary-ownership.md)
12. [Scheduling](tutorial/12-scheduling.md)
13. [Mojo runtime and threads](tutorial/13-runtime-and-threads.md)
14. [Mix integration](tutorial/14-mix-integration.md)
15. [DSL and code generation](tutorial/15-dsl.md)
16. [Debugging native failures](tutorial/16-debugging.md)
17. [Performance engineering](tutorial/17-performance.md)
18. [GPU internals and ownership](tutorial/18-gpu.md)
19. [CI and compatibility](tutorial/19-ci.md)
20. [Design comparison and capstone](tutorial/20-capstone.md)

## Suggested order of commands

```sh
scripts/doctor.sh
scripts/run-abi-experiments.sh
scripts/test-isolated.sh
scripts/inspect-abi.sh
```

If doctor fails, stop. The later commands assume `.venv/bin/mojo` and OTP 28.3.1.

## What you should be able to say at the end

The BEAM wants a `nif_init` that returns a 96-byte `ErlNifEntry` for NIF 2.17, and a callback it will call as a C function. Mojo 1.1.0 emits that callback as a thin function and that entry as a `RegisterPassable` struct whose offsets matched clang. They meet because `dlopen` binds `enif_get_long` to `beam.smp` and the VM calls the function pointer stored in the entry. The result succeeds on this Mac and, for the CPU `add/2`, on the Linux Actions runner: `add(20, 22)` is 42. A separate Apple GPU NIF also returned 42 once (E17). It is not evidence about NVIDIA, concurrent GPU calls, or binaries.
