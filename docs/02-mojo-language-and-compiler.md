# 02 — Mojo language and compiler

## Learning objectives

- Read Mojo 1.1.0 as a compiled language with a C ABI escape hatch.
- Notice which syntax from older Mojo write-ups this compiler rejects.
- Follow a function from `def` to LLVM.

## Why this matters

The NIF is a few dozen lines, but those lines only work because of specific 1.1.0 rules: `def` instead of `fn`, `abi("C")` on every export, `RegisterPassable` structs for C layout, and no mutable globals. Guessing the previous year's syntax wastes a day and produces a file that never reaches the BEAM.

## Mental model

```text
def add(...) abi("C")
        |
        v
   Mojo types + origins          (compile time; erased from the ABI)
        |
        v
   LLVM i64 / ptr on arm64       (what the CPU and dyld see)
        |
        v
   Mach-O in libpoc.so
```

Origins and traits do not appear in `ErlNifEntry`. They stop the compiler from accepting some unsafe programs. Once the object file exists, the CPU sees integers and addresses.

## Theory

Verified on Mojo 1.1.0 by compiling the files in this repo:

- `fn` is removed. The diagnostic says to use `def`.
- `@export("name")` plus `abi("C")` emits a C symbol. Without `abi`, the compiler rejects the export.
- `def` parameters are passed by value unless marked otherwise. `Int64` in the small add experiment became LLVM `i64`.
- Structs that are `RegisterPassable` and hold only C-compatible fields use C field order and C padding. `@fieldwise_init` generates a constructor. This was checked by printing `field_offset`, not assumed from the trait name.
- `from std.ffi import c_int, c_long, c_ulong, c_char, c_size_t` is the width-correct set for this target. `c_long` is 64 bits here. The Mojo manual says every platform it supports today is LP64, and this Mac matches that (`long=8` in the diagnostic).
- `Pointer[T, origin]` is non-nullable. Null is `Optional[Pointer]`, which is 8 bytes on this target, and the empty value is all zero bits.
- A function value with `abi("C")` is described by the compiler as `thin`. Stored in a struct it is 8 bytes. That is the code pointer.
- File-scope `alias` and file-scope `var` are rejected. `comptime` is the compile-time binding used in `fits_int64`.
- `external_call["symbol", ReturnType](args...)` emits a direct call to that C symbol. `mojo build` resolves it at link time. `mojo run` can resolve libc from the process even when a later link would fail. That split is why the NIF is always built with `mojo build`, never exercised only under `mojo run`.
- Traits such as `RegisterPassable` and `Writable` are compile-time constraints. They are not C++ vtables in the NIF struct.
- Overflow: the small `Int64` add in experiment 01 is an LLVM `add` with no check. The NIF does not use that wrapping add on the term path. It rejects out-of-range sums before the `add`.
- SIMD, GPU, and `parallelize` are not used. `from std.gpu import parallelize` fails and the note says those modules moved to the `max` package, which is not installed.
- The pipeline that was observed is Mojo source to LLVM IR (`--emit llvm`) to a linked Mach-O (`--emit shared-lib`). MLIR is not printed by this CLI. Claiming a particular MLIR pass ran would be invention.

`initialize_runtime` exists at `std.runtime`. Calling it does not require a Mojo `main`. See chapter 08 for the BEAM experiment. The add NIF never calls it.

## Hands-on exercise

```sh
.venv/bin/mojo build experiments/abi/01_export_add/add.mojo --emit llvm -o /tmp/add.ll
```

The IR should contain a function `@mojoler_add` that takes two `i64`s and returns an `i64`, and the module triple should contain `arm64-apple-darwin`. The numeric address and the exact feature string can change with the CPU. The `add` instruction is the whole body of that experiment.

Then change `def` to `fn` and rebuild. The diagnostic should name `def` as the replacement.

## Line-by-line walkthrough

[experiments/abi/01_export_add/add.mojo](../experiments/abi/01_export_add/add.mojo):

```mojo
@export("mojoler_add")
def mojoler_add(a: Int64, b: Int64) abi("C") -> Int64:
    return a + b
```

- `@export("mojoler_add")` is the linker name, without Darwin's underscore. `nm` prints `_mojoler_add`.
- `def` defines the function.
- `Int64` is Mojo's fixed 64-bit integer, not Elixir's arbitrary-precision integer.
- `abi("C")` selects the platform C calling convention. On this Mac that is the arm64 AAPCS variant: integer arguments in `x0` and `x1`, result in `x0`.
- `return a + b` became `add i64` in the IR. No Mojo runtime call appears in that function.

## Under the hood

The IR target is `arm64-apple-darwin25.5.0` with `target-cpu=apple-m1`. Darwin 25 is the kernel version corresponding to this macOS 26 install. The function is `dso_local`, which is why `nm` shows a defined text symbol rather than an undefined one.

The shared library still depends on `libKGENCompilerRTShared.dylib` even for this one-line function. The compiler links its runtime into every `--emit shared-lib` output tried here. The add function does not call it, but the image loads it.

## Failure modes

- Using a blog post that starts with `fn main()`. This compiler will not parse it.
- Passing a Mojo `String` to `external_call`. The manual, and this compiler's diagnostics for related APIs, want `as_c_string_span()`.
- Trusting `mojo run` as proof a symbol will link. Build the `.so`.
- Treating `Int64` wraparound as Elixir's `+`. They disagree past `2^63-1`.

## Rustler and Zigler

Rustler's exported functions are Rust `extern "C"` and Zigler's are `export` with a C calling convention. The role of `abi("C")` is that same choice. Neither of those toolchains needs a vendor runtime dylib for an integer add; Mojo 1.1.0 still links `libKGENCompilerRTShared.dylib`. That difference shows up in `otool -L` and in deployment: the BEAM must be able to open that rpath.

## Checkpoint

1. What keyword replaced `fn`? `def`.
2. Why does `nm` show a leading underscore that the source does not? Darwin's C ABI prefix. `dlsym` and `@export` use the unprefixed name.
3. Stretch: add a second exported function that multiplies, rebuild, and confirm both symbols are `T` in `nm -gU`.
