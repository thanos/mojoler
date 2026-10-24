# Unit 20 — Design comparison and capstone

## Objectives

Build a consumer that calls a binary NIF, a resource, and a dirty scheduler, and describe Rustler and Zigler without claiming their safety proofs.

## Why

The point of the library is that an Elixir app can do those three things without writing `ErlNifEntry`. The point of the comparison is to see which guarantees come from a type system we did not run.

## Model

```text
Rustler     Rust crate, rustc, Rust ownership, NIF macros. Not compiled here.
Zigler      Zig, comptime, `zig` toolchain. Not compiled here.
Mojoler     Mojo 1.1.0, generated ABI, JSON declarations, measured on this OTP.
```

## Theory

Rustler's public docs (https://github.com/rusterlium/rustler and the Hex docs at https://hexdocs.pm/rustler) describe deriving NIF wrappers from Rust functions and using Rust's borrow checker on the native side. Zigler's docs (https://github.com/e-xyza/zigler) describe Zig types and comptime checks against the NIF API. This checkout did not clone either project and did not record their versions. Their ergonomic goal — declare a function, get a stub and a safe wrapper — is the same goal as `tools/dsl/decls.json`. The implementation is not the same, and Mojo 1.1.0's origins did not accept every pointer we wanted to write through. Where the compiler could not enforce a lifetime, the code uses a runtime error (`:not_binary`, `:borrowed`, `:frozen`) or refuses the declaration.

Measured Mojoler properties are the ledger, not the resemblance to Rust.

## Lab

```sh
cd examples/consumer && mix test
mix test test/dsl_test.exs test/own_test.exs test/sched_test.exs
```

From the repo root for the second command.

## Expected

The consumer prints a pass for `add(20, 22)`. The second command covers `shift` (copy), `borrow_len` (strict failure on a list), `Box.bump` (resource), and the dirty heartbeat.

## Code

`examples/consumer/lib/consumer.ex` calls `Mojoler.POC.add/2`. The resource and the scheduler are in the main app's tests because the consumer fixture is the packaging proof, not a second copy of every example. A reader adding a function follows unit 15: a JSON object, a user `.mojo` file, `generate.py`, `mix test`.

## Failure

Writing the entry struct in the user file. `native/examples/arith_user.mojo` has no `ErlNifEntry`. If a new example grows one, it has left the DSL.

## Exercise

Name one guarantee Rust's borrow checker is documented to provide that this Mojo code checks only at runtime.

## Answer

Aliasing. Freeze rejects an outstanding borrow by reading a counter under a mutex (`:borrowed`). That is a dynamic check. It is not a compile error in the caller's Elixir, and it is not the Rust rule that a mutable reference excludes other references. The generator does reject a borrow combined with a dirty schedule before compile of that bad file, which is a static check of a declaration, not of arbitrary Mojo.
