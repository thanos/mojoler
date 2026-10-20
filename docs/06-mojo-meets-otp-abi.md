# 06 — Mojo meets the OTP ABI

## Learning objectives

- Walk the eight experiments in order and say what each one allowed the next one to assume.
- Point at the real blocker that did not appear, and at the smaller blockers that did.

## Why this matters

The passing `mix test` is the end of a chain. If a later Mojo release breaks one link, the experiment directory is the place that fails first, before anyone edits the Elixir tests into lying.

## Mental model

```text
01 export symbol
02 store a real code pointer
03 match clang's padding
04 keep the struct alive without a Mojo global
05 runtime init is optional for add, and callable from nif_init
06 export nif_init
07 import enif_get_long, not the macro name
08 dlopen from the BEAM
```

## Theory

Each directory under `experiments/abi/` has a `NOTE.md`. The commands and the text they printed are in `experiments/abi/OBSERVED.txt`.

1. Opaque pointers and function pointers. Thin `abi("C")` functions are 8-byte values and are callable after being stored. `Pointer(to=function)` is a stack address. Opaque `ErlNifEnv*` uses `Pointer[NoneType, MutUntrackedOrigin]`.
2. Struct layout. Mojo `NifFunc` is 32 bytes and `NifEntry` is 96, with the same offsets as clang. `Optional[Pointer]` None is bit-identical to NULL. `Optional` of a thin function is 16 bytes and was rejected for callback fields.
3. Stable descriptor storage. Module-level `var` does not exist. `calloc` does. String literals have `ImmStaticOrigin` and remain readable.
4. Exported callback signature. `add` in `native/poc.mojo` is exactly `(env, argc, argv) -> term`.
5. Callback through a function pointer. Experiment 02 calls the stored pointer. The BEAM does the same with the pointer `nif_init` wrote.
6. `nif_init` returns the calloc'd entry. The symbol is global. The callback symbol is local and mangled (`_poc::add(...)`).
7. `enif_*` access. `external_call` plus `-undefined dynamic_lookup`. The Windows table is not involved. `enif_get_int64` is a macro here.
8. Load and dependencies. `otool -L` shows the NIF, `libKGENCompilerRTShared.dylib` via rpath into the venv, and `libSystem.B.dylib`. ExUnit's fresh OS process completes `add(20, 22) == 42`.

No experiment hit a Mojo bug that made the ABI inexpressible. The real constraints were language rules (no globals, non-null pointers, `fn` removed) and an OTP macro. Both have pure-Mojo expressions that still satisfy the "no C implementation" rule.

## Hands-on exercise

Read `experiments/abi/03_layout/NOTE.md`, then the two layout sections of `OBSERVED.txt`, side by side. You are looking for a size or offset that differs. On the recorded run there is no such line.

Then read `scripts/build-native.sh` and confirm the only source file is `native/poc.mojo`.

## Line-by-line walkthrough

`fits_int64` is part of meeting the ABI, because the values that survive `enif_get_long` are C `long`s and the NIF promised checked Int64 addition:

- If `b > 0` and `a > max - b`, the sum would exceed `2^63-1`.
- If `b` is `INT64_MIN` (detected by `b + (2^63-1) == -1`) and `a < 0`, the sum would go below `-2^63`.
- Otherwise if `b < 0` and `a` is below `INT64_MIN - b`, the sum does not fit.
- `INT64_MIN` is computed as `-(2^63-1)-1` so the literal itself fits in `c_long`.

The tests cover both ends, both orders (`max+1` and `1+max`, `min+(-1)` and `-1+min`), and `min+max == -1`.

## Under the hood

`nif_init` runs once per successful load. It allocates two blocks and returns the entry pointer in `x0`. The VM copies what it needs and keeps the pointer. Because unload is NULL, those blocks are not freed. They are process-lifetime leaks of 32 and 96 bytes plus allocator overhead. That is acceptable for this proof and unsafe as a pattern for a NIF that reloads in a long-lived node. OTP currently refuses the reload anyway.

The local callback does not need to be exported. The VM does not look it up by name. Exporting it would only widen the dynamic symbol table. `nm -gU` showing a single `T _nif_init` is the intended result.

## Failure modes

- A Mojo upgrade that changes `RegisterPassable` layout. Experiment 03 fails the visual diff, and `mix test` may fail inside `load_nif` with `bad_lib` or may crash. Believe experiment 03 first.
- Linking without `-undefined dynamic_lookup`. The build fails with an undefined `_enif_get_long`, or the `.so` binds it to nothing and `dlopen` fails.
- Copying the Windows "fill this struct of pointers from the nif_init argument" pattern. On Unix, `nif_init` takes no arguments. An extra parameter would be a calling-convention bug.

## Rustler and Zigler

Rustler generates steps 6 and 7 from annotations. Zigler generates the struct and can `comptime` assert sizes against its own translated header. Mojoler keeps the steps as separate programs so a failure names the step. The cost is that nothing regenerates `native/poc.mojo` when OTP's minor version moves.

## Checkpoint

1. Which experiment showed that `Pointer(to=function)` is the wrong code pointer? The LLVM probe described in chapter 03; experiment 02 is the version that stores the thin function instead.
2. Why `calloc`? Mojo 1.1.0 has no module-level `var`, and the entry has to outlive `nif_init`.
3. Stretch: delete `-Xlinker -undefined -Xlinker dynamic_lookup` from a copy of the build script and keep the compiler error.
