# Unit 11 — Binary ownership

## Objectives

Tell a borrowed inspect, an explicit copy, a direct output, a frozen resource binary, and a retained term apart by what they return.

## Why

"Zero-copy" is a claim about a measured pointer, not a slogan. This library only says "no payload copy" where a test counted bytes or compared pointers inside the callback.

## Model

```text
borrow_stable   inspect twice, return size and 1 if data pointers match
copy_binary     new bytes, return the copy and the count
fill_output     enif_make_new_binary, write 7s, no earlier payload buffer
blob_poke       write the calloc buffer, token stays
blob_freeze     resource binary points at that buffer
retain_binary   enif_make_copy into a private env
borrow_len      non-binary is an error, not a conversion
```

## Theory

A sub-binary (`binary_part`) is still a binary. `copy_binary` returns those bytes and the byte size. The parent binary's extra bytes are not part of the copy. The test uses a 100-byte prefix and a 3-byte slice.

`<<1::7>>` is not a binary. Both `copy_binary` and `borrow_len` return `{:error, :not_binary}`.

Freeze while a borrow count is outstanding returns `{:error, :borrowed}`. After `blob_release`, freeze returns `{:ok, <<1, 2, 3>>}`. `blob_close` does not invalidate that binary, because `enif_make_resource_binary` holds the resource.

The token from `blob_token` is an integer allocated at creation, not a pointer. Elixir never sees the address. Two pokes leave the token unchanged, which is the reuse evidence.

## Lab

```sh
scripts/demo-cpu.sh
mix test test/dsl_test.exs test/own_test.exs
```

## Expected

The demo prints `copy {:ok, <<1, 2, 3>>, 3}` and `borrow {:ok, 32, 1}`. `borrow_len([1, 2])` fails the DSL test if it ever returns a binary.

## Code

`native/term.mojo` for the three conversion modes. `native/own.mojo` `blob_freeze` and `retain_binary`. `native/generated/bytes.mojo` for the strict borrow.

## Failure

Publishing a mutable buffer as a resource binary and then poking it would change a BEAM binary. Poke checks `frozen` and returns `{:error, :not_mutable}`. The test asserts that.

## Exercise

Why can `borrow_stable`'s third element be 1 without the function returning a pointer?

## Answer

The comparison happens in the callback, and the result is an integer. The pointer dies with the `ErlNifBinary` descriptor, which is `free`d before the return.
