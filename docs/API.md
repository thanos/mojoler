# API

Modules load their `.so` from `priv/native` in `@on_load`. A missing file is a `load_nif` error from OTP, not a silent Elixir fallback that pretends the function ran.

## Mojoler.POC

`add/2` :: integer, integer -> integer. Values that do not fit in signed 64 bits, non-integers, and overflowing sums raise `ArgumentError`.

## Mojoler.Twice

`double/1` :: integer -> integer. Same badarg policy. Implemented with the generated ABI. The source does not declare the NIF structs.

## Mojoler.Term

Domain errors are `{:error, atom}`. Type errors are `ArgumentError`.

- `echo_i64/1`, `echo_u64/1`, `echo_i32/1`, `echo_u32/1`
- `add_i64/2` -> `{:ok, n}` | `{:error, :overflow}`
- `echo_f64/1` — no integer coercion
- `echo_atom/1` — `:ok`, `:error`, `:nil`, `true`, `false`, otherwise `{:error, :unknown_atom}`
- `copy_binary/1` -> `{:ok, binary, nbytes}` | `{:error, :not_binary}`
- `borrow_stable/1` -> `{:ok, size, 1}` when two views share a data pointer
- `fill_output/1` -> `{:ok, binary}` filled with the byte 7, or `{:error, :bad_size}`
- `text_len/1` -> `{:ok, byte_size}` | `{:error, :invalid_utf8}`
- `tuple_sum/1` — arity 2
- `list_sum/1` — proper list, at most 64 integers
- `map_n/1` — key `n`. Extra keys are dropped.

## Mojoler.Own

- `open_counter/0`, `counter_add/2` -> `{:ok, n}` | `{:error, :closed}`, `counter_close/1`
- `open_blob/1`, `blob_token/1`, `blob_poke/3`, `blob_borrow/1`, `blob_release/1`, `blob_freeze/1`, `blob_close/1`, `blob_pin/1`, `blob_dtors/0`
- `retain_binary/1`, `read_retained/1`

Freeze fails with `{:error, :borrowed}` or `{:error, :frozen}`. The resource binary from a successful freeze stays valid after `blob_close/1`.

## Mojoler.Sched

`burn/1` and `hold/2` run on a dirty CPU scheduler. `io_ping/0` runs on a dirty I/O scheduler. `Task.yield/2` does not cancel them.

## Mojoler.Dsl

Generated from `tools/dsl/decls.json`.

- `Mojoler.Dsl.Arith.add/2` -> `{:ok, n}` | `{:error, :overflow}`
- `Mojoler.Dsl.Bytes.shift/1` -> `{:ok, binary, nbytes}`
- `Mojoler.Dsl.Bytes.borrow_len/1` -> `{:ok, size}` | `{:error, :not_binary}`
- `Mojoler.Dsl.Box.open/0`, `bump/2`

## Mix tasks

- `mix compile` — includes `compile.mojoler`
- `mix mojoler.doctor`
- `mix mojoler.abi`
- `mix mojoler.inspect` — optional path, default `priv/native/libpoc.so`

## Not in this API

Raw pointers, a promise that `add/2` is faster than Elixir, GPU as a default dependency, and cancellation of a running NIF. Ownership rules are [ownership.md](ownership.md).
