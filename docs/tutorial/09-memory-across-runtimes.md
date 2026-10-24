# Unit 9 — Memory across runtimes

## Objectives

Pair each allocator with its free, and say which pointers may leave the callback.

## Why

`enif_free` on `calloc` memory crashed `echo_atom` during Stage 2. The two heaps are not interchangeable.

## Model

```text
calloc / free                 descriptors, blob bytes, entry (entry is not freed)
enif_alloc / enif_free        small term arrays in term.mojo
enif_alloc_resource          counter, blob, pin, retained
enif_alloc_env / enif_free_env    retained terms
enif_make_new_binary         OTP owns the returned bytes
```

## Theory

`ErlNifEnv*`, `argv`, and an inspected `data` pointer are valid for the callback. `borrow_stable` reads the pointer, frees the `ErlNifBinary` descriptor with `free`, and returns integers. The public function's return type is a term.

A numeric `ERL_NIF_TERM` copied into another env with `enif_make_copy` is a different value. `read_retained` copies it back into the caller env.

`must_alloc` aborts the process if `calloc` fails. That is a fatal path, not a `{:error, :enomem}` term. The abort probe shows what a fatal path does to a BEAM. Product code uses it only when it cannot construct a return term (no entry, no descriptor).

## Lab

```sh
mix test test/own_test.exs test/term_test.exs
```

## Expected

The retained binary is readable after its process exits. `borrow_stable` of a 1000-byte binary is `{:ok, 1000, 1}`.

## Code

`native/mojoler/abi/prim.mojo` defines `must_alloc` and `must_free`. The comment states they are a pair. `enif_free` is a different pair.

## Failure

Freeing a `calloc` block with `enif_free`, or the reverse, is the crash that made `echo_atom` die after integers and floats had already returned. The repair is the matching deallocator, not a retry.

## Exercise

Which allocation is intentionally leaked until process exit, and what bounds it?

## Answer

The entry and the function table from `nif_init`. OTP keeps the entry pointer, and a second `load_nif` is rejected, so the leak is two blocks per loaded module per OS process. See `docs/stages/s1.md`.
