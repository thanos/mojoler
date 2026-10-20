# 09 — Feasibility report

## Learning objectives

- Apply the word PASS only to the platform that was executed.
- Split blockers into compiler, ABI, runtime, and build tooling.
- Recommend a next step that does not pretend a C shim was required.

## Why this matters

A green test on one Mac is a real result and a narrow one. The useful report says both.

## Mental model

```text
PASS     macOS arm64, OTP 28.3.1, Elixir 1.20.2, Mojo 1.1.0, add/2
PASS     Linux x86-64, same OTP, Elixir, and Mojo, add/2, GitHub-hosted ubuntu-24.04
PASS     one Apple GPU call, MAX 26.6.0, separate NIF, this Mac only
UNTESTED other OTP minors, NVIDIA, Linux GPU, parallelize, unload
```

## Theory

**Verdict: PASS** for the Stage 0 minimum on the tested platform.

Criteria used:

- `Mojoler.POC.add(20, 22) == 42` in ExUnit, in-process and in a fresh OS process.
- The library is the output of `mojo build native/poc.mojo` with no C input.
- `nm` shows `_nif_init` and undefined `_enif_get_long`, `_enif_make_long`, `_enif_make_badarg`.
- Layout offsets match the diagnostic clang program.
- Bad integers and overflow become `ArgumentError` rather than wraparound.

Compatibility matrix:

- OS/CPU: macOS 26.5 arm64, tested. Linux x86-64 tested by [Actions run 39451722783](https://github.com/thanos/mojoler/actions/runs/39451722783): doctor ready, layout offsets match, `runtime ping 7`, ExUnit `11 passed`. See ledger E18 and E19. That job has no GPU.
- OTP: 28.3.1, erts 16.2, NIF 2.17, tested.
- Elixir: 1.20.2-otp-28, tested.
- Mojo: 1.1.0 (`8189361e`), tested. Nightly was not required.

Blockers and workarounds:

- Mojo: no module-level `var`. Workaround: `calloc`. This is still direct Mojo.
- Mojo: `fn` removed; file-scope `alias` of a function type did not parse. Workaround: `def` and an inline thin function type.
- Mojo: `Pointer` is non-nullable, and `Optional` of a thin function is 16 bytes. Workaround: `Optional[Pointer]` for NULL callbacks, measured as 8 zero bytes.
- OTP ABI: `enif_get_int64` is a macro on this build. Workaround: call `enif_get_long` and `enif_make_long`.
- OTP ABI: Darwin `load_nif` appends `.so`. Workaround: name the file `libpoc.so`.
- Runtime: on Darwin, `libKGENCompilerRTShared.dylib` must be on the embedded rpath. Workaround: build inside the project venv and do not relocate the `.so` without that dylib. On the Linux runner, `ldd` of `libpoc.so` lists libc and the dynamic linker only (E19). The venv still contains `libKGENCompilerRTShared.so`; this `add` image does not need it as a `DT_NEEDED` entry.
- Runtime: GPU code lives in the `max` package (26.6.0 here), not in the Mojo 1.1.0 standard library. A one-element Apple GPU add returned 42 from a separate NIF. See ledger E17. NVIDIA, concurrency, and long kernels were not run.
- Build tooling: macOS two-level namespace. Workaround that was verified: `-Xlinker -undefined -Xlinker dynamic_lookup`.

Not a blocker: expressing `ErlNifEntry` in Mojo. Experiment 03 matched clang.

Safety:

- A Mojo trap kills the OS process. Bad arguments do not; they return badarg.
- `env` and `argv` are not stored. Integer results are new terms.
- Two calloc blocks leak until process exit. Unload was not implemented.
- `add` can stall a scheduler only for the duration of a short call. It does not take a dirty flag.
- Upgrade and reload callbacks are NULL. OTP rejects a second load with the message recorded in the ledger.
- The Mojo runtime dylib is in the process even when `initialize_runtime` is not called. Its `dlopen` behavior beyond "the tests passed" was not audited.
- Concurrent `add` passed. Concurrent use of the Mojo thread pool was not run.

Rustler and Zigler, on the axes the prompt asked for:

- ABI generation: they generate the entry and the conversions. Mojoler writes them once and checks offsets with a C diagnostic that is not linked in.
- Type conversion: Rustler and Zigler cover binaries, atoms, lists, and resources. Mojoler converts two `long`s and returns badarg otherwise.
- Scheduler safety: all three can set dirty flags. Only the integer flag value was verified here, and it is 0.
- Compile-time integration: Rustler uses a crate and a build script; Zigler uses Mix plus the Zig compiler. Mojoler shells out to `mojo build` from `test/test_helper.exs`.
- Memory ownership: Rustler has resource types; Zigler has explicit alloc/free. Mojoler has calloc without free and no zero-copy binary.
- Runtime complexity: Zig is the smallest, Rust has its std but not a required thread pool for an add, Mojo links `libKGENCompilerRTShared.dylib`.
- Maintenance: a NIF minor bump means a new offset measurement in this repo. Rustler and Zigler absorb that in their generators, and they also break when they lag OTP.

Recommendation: proceed with direct Mojo for integer-scale NIFs on this ABI. Do not open Stage 0's success to include a C adapter. A C adapter is unnecessary for `add/2` and would throw away the result.

Stage 1, justified by the PASS:

1. Turn the measured struct declarations into a Mojo module that other NIFs import, still compiled only from `.mojo` files.
2. Generate the constants (`minor`, resource size, `min_erts`, `vm_variant`) from the diagnostic program's output so an OTP bump is a regenerated file plus a re-run, not a hand edit.
3. Add `enif_make_atom` and a copied binary only after a lifetime test like chapter 07's stretch.
4. Keep `-undefined dynamic_lookup` behind the same build script, and fail `doctor` when the KGEN dylib is missing.
5. The CPU matrix has now been repeated on Linux x86-64 (E18, E19). Portability still does not include a GPU on Linux, another OTP minor, or NVIDIA.

## Hands-on exercise

Run `scripts/doctor.sh`, `scripts/run-abi-experiments.sh`, and `scripts/test-isolated.sh`. PASS for a new checkout means doctor prints `ready`, the layout sections agree, and ExUnit prints `11 passed`. Any one of those failing moves that checkout to PARTIAL or BLOCKED. Do not copy this chapter's verdict onto a log you have not produced.

## Line-by-line walkthrough

The verdict is tied to [test/poc_test.exs](../test/poc_test.exs):

- `add(20, 22) == 42` is the minimum demonstration.
- The overflow tests are the "checked Int64" requirement.
- The `nm` test is the "no silent C shim" requirement inside the suite.
- The fresh `elixir -e` test is the "separate OS process" requirement.

If the `nm` test passes and the arithmetic tests fail, the ABI loaded and the logic is wrong. If `load_nif` fails, the arithmetic tests never run and the verdict is not PASS.

## Under the hood

The compiler-inserted libc symbols (`write`, `dup`, `fdopen`, `fflush`, `fclose`) are visible in the LLVM module for `poc.mojo`. They are why "no C source file" and "the process never executes libc" are different sentences. The proof in [direct_mojo_proof.md](direct_mojo_proof.md) claims the first. It does not claim the second.

## Failure modes

- Reporting PASS for Linux because arm64 matched the manual's LP64 comment.
- Reporting BLOCKED because a C file exists under `experiments/abi/diagnostic/`. That file is not linked. Check `scripts/build-native.sh`.
- Reporting that Mojo is faster than Elixir. The measured loop is slower. See chapter 08.

## Rustler and Zigler

Choose Rustler or Zigler today if you need binaries, resources, dirty schedulers, and more than one OTP version without re-measuring structs by hand. Choose more Mojo only if the point of the project is the Mojo implementation itself. Stage 0 shows that the implementation is possible for this function. It does not show that it is a better default than Rustler for an ordinary Elixir library.

## Checkpoint

1. What is the verdict on this Mac? PASS.
2. What is the verdict on Linux CPU `add/2`? PASS, from the green Actions log in E18 and E19. That is not a GPU verdict.
3. What remains untested? NVIDIA, a GPU call on Linux, concurrent GPU calls, and unload.
