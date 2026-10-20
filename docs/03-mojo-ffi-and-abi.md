# 03 — Mojo FFI and the C ABI

## Learning objectives

- Export a C function and call a C function from Mojo.
- Read a pointer origin as a compile-time fact that is not stored in the struct.
- Explain why a working `add` export is not a NIF.

## Why this matters

The BEAM will call `nif_init` and later the function pointer inside `ErlNifFunc` with the C calling convention. If Mojo inserts a hidden environment argument, or if a "pointer to the function" is actually a pointer to a stack temporary, the VM jumps to garbage. This chapter is the difference between those two.

## Mental model

```text
Elixir integer 20          not an Int64 yet
        |
        v
BEAM term (64-bit unsigned long on this Mac)
        |
        v
enif_get_long writes a C long
        |
        v
Mojo c_long, then enif_make_long builds a new term
```

Experiment 01 stops at the middle box. It never sees a term.

## Theory

`external_call` is a direct native call. The return type parameter must be `RegisterPassable`. Argument types are inferred from the values you pass, so a wrong Mojo type becomes a wrong C declaration with no header check. Two different signatures for one symbol in one module fail at build time.

`OwnedDLHandle()` with no path opens the current process and looks symbols up at runtime. That was the fallback if `-Xlinker` could not express dynamic lookup. `mojo build --help` does expose `-Xlinker`, and `-undefined dynamic_lookup` linked, so the NIF uses `external_call` instead. Runtime `dlsym` remains a viable pure-Mojo alternative; it was not needed for the passing build.

String literals: `"add".as_c_string_span().ptr()` has origin `ImmStaticOrigin`. The bytes live in the binary. `unsafe_ptr` is deprecated in favor of `ptr()` on this version.

`MutUntrackedOrigin` is the origin for pointers the compiler should not tie to a Mojo value: `ErlNifEnv*`, the argv array, and `calloc` memory. Using it is a promise that the NIF will not store those pointers. `native/poc.mojo` keeps that promise for `env` and `argv`. The calloc'd entry is intentionally kept, and the VM holds the only long-lived pointer to it.

## Hands-on exercise

Run `scripts/run-abi-experiments.sh`. In `experiments/abi/OBSERVED.txt`:

- section 01 should list `_mojoler_add` as a defined `T` symbol and should list `libKGENCompilerRTShared.dylib`
- section 02 should print `sizeof 8` and `result 42`
- section 03 should print `NifFunc sizeof 32` and `NifEntry sizeof 96`

The addresses in `otool` paths will match your checkout. The sizes should not change unless you change Mojo, OTP, or the struct fields.

## Line-by-line walkthrough

The callback in [native/poc.mojo](../native/poc.mojo):

```mojo
def add(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
```

- `env` is `ErlNifEnv*`. The pointee is opaque. Mojo never defines the struct.
- `argc` is C `int` (`c_int`, 32 bits).
- `argv` points at `ERL_NIF_TERM` values. On this ABI that is `unsigned long`, so the element type is `c_ulong`.
- The return is the new term, also `c_ulong`.
- `abi("C")` makes the value thin, so it can be stored in `NifFunc.fptr`.

`argv[unsafe_offset=0]` loads one term. The index is scaled by the element size. The pointer is not retained after the call.

`external_call["enif_get_long", c_int](env, term, Pointer(to=a))` matches `int enif_get_long(ErlNifEnv*, ERL_NIF_TERM, long*)`. Zero means the term was not an integer in range. The NIF turns that into `enif_make_badarg`.

## Under the hood

An earlier probe printed `Pointer(to=cb)` and the IR was:

```text
store ptr @"...closure_0", ptr %4
%5 = ptrtoint ptr %4 to i64
```

`%4` is a stack slot. The integer that came out was the slot's address, not the function's address. A NIF entry built that way would crash on the first call. Storing the thin function value stores the code pointer. Experiment 02 calls that stored pointer and gets 42, which is the check.

arm64 passes the NIF callback as `env` in `x0`, `argc` in `w1`, `argv` in `x2`, and returns the term in `x0`. The LLVM `ptr, i32, ptr` to `i64` signature is that convention. Nothing in this repo single-steps the registers in a debugger; the IR and the passing ExUnit test are the evidence that the convention matched.

## Failure modes

- Storing `Pointer(to=function)` in the entry. First call jumps into the stack.
- Declaring `enif_get_long`'s out-parameter as `c_int`. The VM writes 8 bytes.
- Using `Optional` of a thin function for a NULL callback. Measured size is 16, so it would shove every later field. Use `Optional[Pointer[NoneType, ...]]`, whose empty value is 0.
- Forgetting `abi("C")` on the callback. It will not match the field type, or it will not be a C function if you force it.

## Rustler and Zigler

Rustler encodes the same callback as an `extern "C" fn(*mut ErlNifEnv, i32, *const ERL_NIF_TERM) -> ERL_NIF_TERM`. Zigler uses a C-compatible function pointer in a `extern struct`. The Mojo field type is that pointer, written inline because a file-scope `alias` of a `def` type did not parse.

Both projects still need a correct `ErlNifEntry` after they can export `add`. Chapter 04 is that missing half.

## Checkpoint

1. Why is experiment 01 not a NIF? It never returns an `ErlNifEntry` and never calls `enif_*`.
2. What measured fact makes `Optional[Pointer]` usable as a NULL callback? It is 8 bytes and None is all zeros.
3. Stretch: change the callback return type to `c_int` and watch the struct size or the call fail. Restore it afterward.
