# Mojoler tutorial

This is the guided path through the Stage 0 proof: a Mojo shared library that the BEAM loads as the NIF `Elixir.Mojoler.POC.add/2`.

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
10. [09 — Feasibility](09-feasibility-report.md). PASS on this Mac, untested on Linux.

## Suggested order of commands

```sh
scripts/doctor.sh
scripts/run-abi-experiments.sh
scripts/test-isolated.sh
scripts/inspect-abi.sh
```

If doctor fails, stop. The later commands assume `.venv/bin/mojo` and OTP 28.3.1.

## What you should be able to say at the end

The BEAM wants a `nif_init` that returns a 96-byte `ErlNifEntry` for NIF 2.17, and a callback it will call as a C function. Mojo 1.1.0 emits that callback as a thin function and that entry as a `RegisterPassable` struct whose offsets matched clang. They meet because `dlopen` binds `enif_get_long` to `beam.smp` and the VM calls the function pointer stored in the entry. The result succeeds on this Mac: `add(20, 22)` is 42, and the suite around it passed. It is not evidence about Linux, GPUs, or binaries.
