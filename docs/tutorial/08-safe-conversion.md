# Unit 8 — Safe conversion design

## Objectives

State the policy for integers, floats, atoms, binaries, lists, and maps, and point at the test that locks it.

## Why

A NIF that accepts every term will create atoms without bound or treat a bitstring as bytes. Both are OTP footguns.

## Model

```text
enif_get_* fails  ->  ArgumentError     (bad argument)
value is in range but the operation is not  ->  {:error, reason}
literal atom only ->  the error reason
```

## Theory

Integers: the width is the `enif_get_long` / `enif_get_ulong` / `enif_get_int` / `enif_get_uint` that the function calls. Just outside the 64-bit range is a bignum and becomes badarg. Negative-to-unsigned is badarg.

Floats: `enif_get_double` does not accept an integer. This OTP will not build a NaN with `0.0 / 0.0`. It raises `ArithmeticError`. The NIF's `n != n` branch is defensive and was not fed a term.

Atoms: `echo_atom` compares against five literals. `:other` is `{:error, :unknown_atom}`. The error atom is also a literal.

Lists: `enif_get_list_length` fails on an improper list. Length above 64 is `:too_long`. A nested list is `:bad_element` (depth 1). The walk is a loop.

Maps: missing `n` is `:missing`. Extra keys are dropped. That is the unknown-field policy, and the test checks `%{n: 7, extra: 1}`.

## Lab

```sh
mix test test/term_test.exs
```

## Expected

The integer edges, the overflow tuple, the atom vocabulary, the sub-binary copy, and the improper list all pass.

## Code

`native/term.mojo`. `fits_int64` is the same overflow idea as `poc.mojo`: the check itself stays inside `c_long`.

## Failure

Returning `enif_make_atom(env, user_bytes)` would let a caller create atoms. The code does not take that path. If a new error reason is needed, add a literal and a test.

## Exercise

What does `copy_binary(<<1::7>>)` return, and why?

## Answer

`{:error, :not_binary}`. `enif_inspect_binary` rejects a bitstring that is not a whole number of bytes. The NIF does not pad it.
