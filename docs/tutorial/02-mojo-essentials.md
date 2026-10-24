# Unit 2 — Mojo language essentials

## Objectives

Read the subset of Mojo 1.1.0 this repo actually compiles: `def`, structs, origins, and the absence of file-scope `alias`.

## Why

A snippet from an older Mojo post uses `fn` or `alias` and never reaches the linker. The NIF bug then looks like an OTP bug.

## Model

```text
def name(...) abi("C") -> c_ulong     callback the VM calls
struct ... (RegisterPassable)         C layout, if the fields match
Pointer[T, MutUntrackedOrigin]        VM or calloc memory
[o: Origin]                           a pointer to a local the callee may use
```

## Theory

`def` replaced `fn` (E4). There is no module-level `var` (E9), which is why `nif_init` calls `calloc`. A file-scope `alias` is a parse error in this compiler, so `abi_major()` is a function that returns `c_int(2)`.

`Pointer` is non-null. Failure is `Optional[Pointer]`. `Optional` of a thin function was 16 bytes and cannot sit in a callback slot. `Optional[Pointer]` is 8 bytes and None is all zeros (E7).

Writing through `Pointer[T, MutUntrackedOrigin]` from Mojo failed when the argument was a local (`origin_of(result)`). The ABI wrappers take `[o: Origin]` so `Pointer(to=local)` typechecks. A Mojo function that needs to *store* through that pointer is a different problem: the user arithmetic returns an `AddResult` struct instead of writing through the pointer.

## Lab

Open `native/mojoler/abi/otp_nif.mojo` and `native/examples/arith_user.mojo`. Confirm there is no line that starts with `alias`.

## Expected

Constants are `def abi_...` functions. `checked_add` returns `AddResult`.

## Code

`native/poc.mojo` is the short version of the same rules: one struct assignment into memory from `alloc_funcs`, one `make_entry`, one exported `nif_init`.

## Failure

`cannot implicitly convert` on a pointer origin means the wrapper's origin parameter was pinned to `MutUntrackedOrigin` or `MutAnyOrigin` and the local does not match. The fix used here is a generic origin, not a cast that throws the check away without a comment.

## Exercise

Why is `enif_get_int64` absent from the generated imports?

## Answer

On this OTP it is a macro for `enif_get_long` because `SIZEOF_LONG` is 8 (E6). The generator records that in a comment and emits `enif_get_long`.
