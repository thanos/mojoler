# Unit 7 — OTP ABI automation

## Objectives

Regenerate the bindings, watch a clean check, and see a refused declaration of a foreign triple.

## Why

Hand-copied structs drift the first time the header gains a field. The generator fails closed on types it does not know.

## Model

```text
erl_nif.h  --clang AST-->  generate.py  -->  otp_nif.mojo
                |                              |
                +-- dM -E macros               +-- --check diffs bytes
                +-- C sizeof probe (not linked)
```

## Theory

Two copies of `erl_nif.h` exist under the asdf OTP install. The generator prefers `usr/include` and exits if the hashes differ. `tools/abi/pin.json` requires NIF 2.17, 64-bit little-endian, and `SIZEOF_LONG` 8.

Anonymous structs are recognized by field names (`size, data, ref_bin, __spare__` is `ErlNifBinary`). Unknown types abort the generator. Variadic `enif_make_tuple` is not wrapped; callers use `enif_make_tuple_from_array`.

The manifest next to the Mojo file records the host compiler and triple. `--check` does not diff the manifest, because a Linux host would disagree with a committed Darwin manifest. The Mojo declarations are the stable artifact. The manifest is gitignored.

## Lab

```sh
python3 tools/abi/generate.py --check
```

## Expected

`abi mojo: matches` is also printed by `scripts/check-abi.sh`. A dirty working tree of `otp_nif.mojo` prints a diff and exits non-zero.

## Code

Header comments in `otp_nif.mojo` include the header sha256. If you change the allowlist in `tools/abi/functions.txt`, you must regenerate and commit both.

## Failure

Simulating header drift: point the generator at a different OTP than the pin. It should exit before writing a library. Do not "fix" that by editing the pin to match an untested minor.

## Exercise

Where are dirty-scheduler constants read from, given they are not in `clang -dM` output?

## Answer

From the AST enum value of `ERL_NIF_DIRTY_JOB_CPU_BOUND` and `ERL_NIF_DIRTY_JOB_IO_BOUND`. `scripts/check-abi.sh` prints those C constants and diffs them with `abi_dirty_cpu` / `abi_dirty_io`.
