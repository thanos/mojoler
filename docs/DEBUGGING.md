# Debugging

Run crashing experiments in a new OS process. `scripts/test-isolated.sh` alarms `mix test` after 180 seconds. A NIF that traps takes the whole BEAM with it; do not debug that inside a long-lived `iex` you care about.

## Build failures

`mojo build` writes the diagnostic to stderr. `'fn' has been removed` means the snippet is older than 1.1.0. `global variables are not supported` means the state has to move into a function or into `calloc`. An undefined `_enif_get_long` at link time means `-Xlinker -undefined -Xlinker dynamic_lookup` was dropped.

`Failed to initialize Crashpad` comes from the Mojo driver, not from the NIF. The build's exit status is the signal that matters.

## Symbols

```sh
scripts/inspect-abi.sh
nm -gU priv/native/libpoc.so
nm -u priv/native/libpoc.so
nm priv/native/libpoc.so | rg "nif_init|add"
```

You want one global `_nif_init`, undefined `_enif_get_long`, `_enif_make_long`, and `_enif_make_badarg`, and a local `t` symbol for `add`. A missing `_nif_init` means `@export("nif_init")` did not make it into this file. An exported `enif_get_int64` means the wrong name was chosen for this OTP.

## Dependencies

```sh
otool -L priv/native/libpoc.so
otool -l priv/native/libpoc.so | awk '/LC_RPATH/,/path /'
```

If `dlopen` fails with an image-not-found error for `libKGENCompilerRTShared.dylib`, the rpath does not point at the venv that built the library, or the `.so` was copied to a machine without that file.

## Load failures

Elixir prints `bad_lib` when the entry name does not match the calling module, or when the version or `vm_variant` is rejected. The message text is the artifact. Copy it into the ledger. `{:error, {:reload, ...}}` on a second load is OTP policy since OTP 20, observed as `NIF library already loaded (reload disallowed since OTP 20).`

Confirm the suffix by looking at the path in the error. This OTP wants `.so` even on Darwin.

## Layout drift

Re-run `scripts/run-abi-experiments.sh` and diff the Mojo offsets against the clang offsets. Do this before rewriting `fits_int64`. A crash on the first call, with a successful `mojo build`, is often a function pointer that points at a stack slot or a struct field that slid by four bytes.

## Debuggers

`mojo debug` exists in `mojo --help`. It was not used for the passing run. `lldb -- beam.smp` can break on `nif_init` after `dlopen` if you need registers; a trap will look like `EXC_BAD_INSTRUCTION` or a Mojo abort rather than an Elixir stack. `otool -tv` disassembles the Mach-O. Prefer `--emit llvm` on the small `add.mojo` when the question is "what did the compiler mean", because the full NIF IR is large and includes compiler-runtime calls.

## Crash dumps

`erl_crash.dump` in the repo root means the VM died. It is gitignored. Keep it next to the command that produced it. Do not reopen a session that loads the NIF again until the dump's culprit is at least classified as badarg-versus-trap: badarg is an `ArgumentError` and does not write a dump; a dump means the process actually died.
