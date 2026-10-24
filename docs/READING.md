# Reading

Versions are the ones doctor printed. Header paths are for the asdf install of Erlang 28.3.1. Mojo pages were checked by compiling; where the page and the compiler disagreed, the compiler won (`fn` is gone).

## OTP

- `~/.asdf/installs/erlang/28.3.1/erts-16.2/include/erl_nif.h` — `ErlNifEntry`, `ErlNifFunc`, `ERL_NIF_INIT`, version macros 2.17. The non-Windows `nif_init` declaration is the contract Mojo reimplements.
- `erl_nif_api_funcs.h` beside it — real declarations versus the `SIZEOF_LONG == 8` macros that rename `enif_get_int64`.
- `erl_int_sizes_config.h` — `SIZEOF_LONG 8` on this build.
- `erl_drv_nif.h` — dirty-job constants 1 and 2.
- `erts-16.2/bin/beam.smp` — the process image that exports `_enif_get_long`, `_enif_make_long`, and `_enif_make_badarg`.
- Erlang reference, `erlang:load_nif/2` — path without suffix, `@on_load`, reload rules. The observed reload text is in the ledger, not paraphrased from memory.

## Mojo 1.1.0

- `mojo build --help` on the venv binary — `--emit shared-lib`, `--emit llvm`, `-Xlinker`. This is the authority for flags.
- <https://mojolang.org/docs/manual/values/> — one owner per value. The local write-up is [ownership.md](ownership.md).
- <https://mojolang.org/docs/manual/values/ownership/> — argument conventions and the `^` transfer.
- <https://mojolang.org/docs/manual/lifecycle/> — initializers and as-soon-as-possible destruction.
- <https://mojolang.org/docs/manual/quickstart/>, <https://mojolang.org/docs/manual/get-started/>, <https://mojolang.org/docs/tools/notebooks/> — the language tours the README examples come from.
- <https://mojolang.org/docs/manual/c-ffi/> — `external_call`, `std.ffi` aliases, `OwnedDLHandle`, `RegisterPassable` layout, `MutUntrackedOrigin`.
- <https://mojolang.org/docs/reference/decorators/export/> — `@export` and `abi`.
- <https://mojolang.org/docs/std/runtime/initialize_runtime/> — process-global init. The BEAM experiment is chapter 08; the page is not a substitute for that log.
- Compiler diagnostic `'fn' has been removed; use 'def' instead` — older posts that start with `fn` are historical.

## This repo

- [evidence-ledger.md](evidence-ledger.md) — commands and outputs.
- [direct_mojo_proof.md](direct_mojo_proof.md) — why the `.so` is the Mojo file.
- `experiments/abi/OBSERVED.txt` — the layout and export runs.
- `experiments/abi/diagnostic/layout.c` — offsetof printer. Not part of the NIF link.
