# Glossary

**ABI.** The binary contract: register widths, stack layout, struct padding, symbol names. Not the same as a source API. Mojo `Int64` and C `long` can match on this Mac and still be different types in the source.

**`abi("C")`.** Mojo effect that makes a function use the platform C calling convention. The compiler describes that value as `thin`.

**BEAM.** The Erlang virtual machine that executes Elixir. `beam.smp` is the executable that exports `enif_*` and `dlopen`s NIFs.

**`calloc`.** libc allocator that returns zeroed memory. `nif_init` uses it because Mojo 1.1.0 has no module-level variable. Those two blocks stay until the process exits. `Mojoler.Own` uses `free` on its private box in `unload`. `enif_free` is a different allocator.

**Dirty scheduler.** A BEAM scheduler reserved for NIFs that set `ERL_NIF_DIRTY_JOB_CPU_BOUND` (1) or `ERL_NIF_DIRTY_JOB_IO_BOUND` (2) in `ErlNifFunc.flags`. `add` sets 0.

**Dynamic loader.** dyld on this Mac, ld.so on Linux. It maps the `.so` and binds undefined symbols. Two-level namespace on Darwin does not bind NIF symbols to `beam.smp` unless the library was linked with `-undefined dynamic_lookup`.

**`enif_get_int64`.** A macro for `enif_get_long` in this OTP because `SIZEOF_LONG` is 8. Not a symbol you can import.

**`ErlNifEntry`.** The struct `nif_init` returns. 96 bytes in erts 16.2 on this Mac. See [05-otp-abi-map.md](05-otp-abi-map.md).

**`ErlNifEnv`.** Opaque VM handle passed to each NIF call. Valid for that call. Not stored by this NIF.

**`ErlNifFunc`.** One exported NIF function: name, arity, code pointer, flags. 32 bytes here.

**`ERL_NIF_TERM`.** Unsigned integer the width of a pointer. 8 bytes here. Not a Mojo pointer.

**Immediate / boxed term.** How the VM packs small integers versus heap objects inside an `ERL_NIF_TERM`. This NIF does not inspect the tag. `enif_get_long` does.

**LLVM.** The compiler IR `mojo build --emit llvm` writes. The small add lowers to `add i64`. MLIR is an earlier stage this CLI did not print.

**Mach-O.** macOS object-file format. `file` reports `Mach-O 64-bit dynamically linked shared library arm64`. ELF is the Linux counterpart. The Ubuntu runner produced it: `nm` printed `T mojoler_add` with no leading underscore (E18).

**`MutUntrackedOrigin`.** A Mojo origin that opts out of lifetime checking. Used for VM pointers and `calloc` memory. It is a promise, not a check.

**NIF.** Native Implemented Function. Erlang loads a shared library and calls C-ABI functions with the NIF API.

**`nif_init`.** The symbol a dynamically loaded NIF must export. Returns `ErlNifEntry*`. On Darwin, `nm` prints `_nif_init`.

**Origin.** Compile-time provenance of a Mojo pointer. `ImmStaticOrigin` is the origin of a string literal. Origins are not bytes in the struct.

**Owner.** The single Mojo variable that owns a value. When its lifetime ends, Mojo destroys the value. See [ownership.md](ownership.md).

**Transfer (`^`).** Moves ownership to a new name. The source is uninitialized afterward.

**Lifecycle.** Construction in `__init__(out self)`, use, then destruction in `__deinit__(deinit self)` at the last use.

**OTP.** Open Telecom Platform, the Erlang distribution. Version 28.3.1, emulator erts 16.2.

**Reduction.** VM accounting unit for Erlang work. NIFs do not automatically consume reductions.

**Resource.** A VM-managed object with a destructor. Stage 0 did not allocate one. Stage 3 does, in `Mojoler.Own`. The init struct is still 40 bytes, and that size is stored in the entry as a version tag. The BEAM term is a handle. Elixir code never receives the native pointer.

**Borrowed view.** A pointer from `enif_inspect_binary` that is valid only for the callback. `borrow_len` and `borrow_stable` read it and then free the descriptor. They do not return the pointer.

**Fingerprint.** The sha256 `scripts/fingerprint.sh` prints. The Mix compiler skips `mojo build` when that line still matches `priv/native/FINGERPRINT` and the libraries are present.

**rpath.** A Mach-O load command that says where to find `@rpath/...` dependencies. This NIF's rpath points at the project venv's `modular/lib`.

**Scheduler.** An OS thread that runs Erlang processes. A normal NIF runs on the scheduler that called it.

**Symbol.** A named address in an object file. `T` in `nm` is a global defined text symbol. `t` is a local one. `U` is undefined.

**Thin function.** Mojo's term for a C function pointer with no captured environment. Eight bytes on this target.

**`vm_variant`.** String in the entry that must match the running emulator. `"beam.vanilla"` in this header.
