# 00 — Environment and sources

## Learning objectives

- Name the exact compilers and the OTP headers this proof used.
- Tell a preprocessor macro from a function the dynamic linker can see.
- Say which platform was actually executed.

## Why this matters

A NIF is a contract with one OTP build and one CPU ABI. Elixir 1.20 on OTP 28 is not the same binary contract as OTP 27, and macOS arm64 is not the same loader contract as Linux. Writing the versions down is what makes a later failure diagnosable.

## Mental model

```text
source (Mojo) --mojo build--> Mach-O .so --dlopen by beam.smp--> nif_init()
                                  |                               |
                                  +-- undefined enif_* -----------+-- defined in beam.smp
```

The `.so` does not contain the Erlang runtime. It expects the process that loads it to already be the BEAM.

## Theory

`scripts/doctor.sh` checks the platform (Darwin arm64 or Linux x86-64), Elixir, Erlang, Mix, a C compiler, nm, otool on Darwin or ldd on Linux, `.venv/bin/mojo`, `erl_nif.h` from `code:root_dir()`, and `libKGENCompilerRTShared`.

Pinned versions from that script:

- macOS 26.5, arm64, Apple clang 17.0.0, ld 1230.1
- Erlang/OTP 28.3.1, erts 16.2
- Elixir 1.20.2
- Mojo 1.1.0, commit `8189361e`

`erl_nif.h` in that erts defines `ERL_NIF_MAJOR_VERSION` 2 and `ERL_NIF_MINOR_VERSION` 17. For a non-Windows, non-static NIF, `ERL_NIF_INIT` expands to a default-visibility function named `nif_init` that returns `ErlNifEntry*`. `STATIC_ERLANG_NIF` is what renames it to `Module_nif_init`. This project does not define that macro, and the Mojo source exports `nif_init` itself instead of going through the C macro.

`enif_get_int64` is not always a function. In `erl_nif_api_funcs.h`, the declarations of `enif_get_int64` and `enif_make_int64` are wrapped in `#if SIZEOF_LONG != 8`. This install's `erl_int_sizes_config.h` sets `SIZEOF_LONG` to 8, so those names become macros for `enif_get_long` and `enif_make_long`. A macro disappears before the linker runs. `nm` on `beam.smp` shows `_enif_get_long`, `_enif_make_long`, and `_enif_make_badarg`, and does not show `_enif_get_int64`.

On Windows the same header builds a struct of function pointers (`TWinDynNifCallbacks`) and fills it in from the `nif_init` argument. The Unix branch does not. Calling a function-pointer table on this Mac would be an invented ABI.

`mojo build --help` on 1.1.0 lists `--emit shared-lib` and `-Xlinker`. That is the linker escape used to pass `-undefined dynamic_lookup`.

Primary files:

- `~/.asdf/installs/erlang/28.3.1/erts-16.2/include/erl_nif.h`
- `erl_nif_api_funcs.h` and `erl_int_sizes_config.h` beside it
- `erts-16.2/bin/beam.smp`
- Mojo manual for `@export` and `std.ffi` at <https://mojolang.org/docs/manual/c-ffi/>, checked against this compiler rather than trusted in advance

## Hands-on exercise

Run `scripts/doctor.sh`. A ready machine ends with `doctor: ready`. A missing Mojo binary ends with the `uv venv && uv pip install -r requirements.txt` line and a non-zero status.

Then run:

```sh
nm -gU "$(dirname $(which erl))/../erts-16.2/bin/beam.smp" | rg "enif_get_long|enif_make_long|enif_make_badarg|enif_get_int64"
```

The shape of a successful listing is three `T` symbols for the long and badarg functions, and no `enif_get_int64` line. If your OTP is not 28.3.1, the path will differ; use `scripts/doctor.sh` rather than this hardcoded path.

## Line-by-line walkthrough

`ERL_NIF_INIT` in the installed header, non-Windows branch:

```text
ERL_NIF_INIT_EXPORT ErlNifEntry* nif_init(void)
```

The body fills a `static ErlNifEntry` and returns its address. Mojo 1.1.0 has no equivalent `static` local that outlives the function (module-level `var` is rejected), so [native/poc.mojo](../native/poc.mojo) `calloc`s the entry instead. The bytes of the struct are the same idea: major, minor, name, function table, four callbacks, `vm_variant`, options, resource-init size, `min_erts`.

## Under the hood

Apple's dynamic linker uses a two-level namespace. An undefined symbol in a dylib is not looked up in the main executable unless the dylib was linked with flat lookup. `beam.smp` is not a dylib the NIF linked against by install name; it is the process image. `-undefined dynamic_lookup` tells the linker to leave `_enif_get_long` undefined. When the BEAM `dlopen`s the NIF, dyld binds it to the copy already in the process.

`strings` on `beam.smp` contains `nif_init`. The loader looks that name up with `dlsym`. The Mach-O symbol table prints it as `_nif_init` because the C ABI prefix on Darwin is an underscore. `dlsym` takes the unprefixed name.

## Failure modes

- `doctor` fails on `mojo`: the venv was not created, or it was created with a different Python. Recreate it from `requirements.txt` (`mojo==1.1.0`).
- `nm` on `beam.smp` shows `enif_get_int64`: this is not the LP64 OTP this repo measured. Stop and re-measure before reusing `enif_get_long`.
- A crashpad line on stderr (`Failed to initialize Crashpad`) comes from the Mojo driver. Builds still return 0. It is not a NIF failure.

## Rustler and Zigler

Rustler and Zigler also pass `-undefined dynamic_lookup` on macOS, for the same dyld reason. They generate the init function from bindings. This repo writes that function in Mojo and checks the symbols with `nm`. The comparison that matters here is the lookup rule, not the source language.

## Checkpoint

1. Why is `enif_get_int64` the wrong symbol to import on this Mac? Because `SIZEOF_LONG` is 8, so the header macro-renames it to `enif_get_long`, and that is the symbol `beam.smp` exports.
2. What is the dynamic NIF's init symbol? `nif_init`.
3. Stretch: rebuild the diagnostic layout program under `scripts/run-abi-experiments.sh` after an OTP upgrade and diff `experiments/abi/OBSERVED.txt` before touching `native/poc.mojo`.
