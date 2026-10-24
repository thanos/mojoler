# 07 — Memory and lifetime

Stage 0 left binary ownership untested. Stage 3 measured borrow, copy, freeze, pin, and retain. The two `calloc` blocks for the NIF entry are still process-lifetime, and that bound is [stages/s1.md](stages/s1.md). The rest of this chapter is the Stage 0 account.

## Learning objectives

- Name who owns each pointer in `add` and how long it lives.
- Refuse a zero-copy binary design until an ownership protocol has been tested.
- See the two `calloc` blocks as process-lifetime leaks, not as VM resources.

## Why this matters

The integer NIF is safe mostly because it does not remember anything. The first time someone stores `env`, or returns a pointer into a Mojo `String` as if it were an Erlang binary, the crash will be far from the line that created the pointer.

## Mental model

```text
call starts
  env  ---- valid until return ----.
  argv ---- valid until return ----|
  a, b on the Mojo stack            |
  result term allocated by enif_*   v
call returns                        all of the above are dead
                                    except the term now owned by the VM

process starts
  calloc entry + funcs  ---- valid until the OS reaps the process
  string literals       ---- valid for the life of the mapped .so
```

## Theory

Borrowed BEAM memory: `argv[i]` is a term value, not a pointer to a buffer this NIF may keep. Even if a term is a boxed object internally, Mojo must not chase it. `enif_get_long` copies the integer onto the stack.

Native allocations: `calloc` memory is owned by the NIF code, not by the VM. There is no destructor. `free` is not called. A correct unload callback would free both blocks, and only if the VM promises not to touch the entry afterward. That promise was not tested, because unload is NULL and OTP will not reload this library in-process.

Resource objects: not used. A resource is the VM's answer to "native memory that should die when the term dies". Building one requires `enif_open_resource_type` or `enif_init_resource_type`, a 40-byte `ErlNifResourceTypeInit`, and a destructor that must not call back into Mojo in a way that re-enters a dead runtime. None of that was implemented. The size field is still filled in so the entry matches the header.

Refcounting: Erlang binaries and resources use VM refcounts. Mojo's origins are a compile-time overlay and the VM does not honor them. `MutUntrackedOrigin` means "Mojo has stopped checking". It does not mean the memory is immortal.

Cross-thread: `add` does not start a thread. Concurrent Elixir calls run the same code on scheduler threads. The only shared Mojo state is the immutable entry (function pointer and string literals) and whatever `libKGENCompilerRTShared.dylib` does on load. The concurrent ExUnit test passed. That is not a proof that `initialize_runtime`'s thread pool is safe on scheduler threads. The add NIF never starts that pool.

Zero-copy binaries are not implemented. A retained binary would require a tested rule for who frees the bytes and what happens on unload. Guessing "Mojo alloc, BEAM reads" is how use-after-free enters a NIF.

## Hands-on exercise

In `native/poc.mojo`, confirm there is no field on `NifEntry` that has type `Pointer` to `ErlNifEnv` or to the argv element. The entry fields are integers, string literals, the funcs pointer, optional null callbacks, and the resource-size integer.

Run the repeated-call test (`Enum.map(1..200, ...)`) by running `mix test`. A use-after-free often survives one call and dies on the second. Two hundred calls passed.

## Line-by-line walkthrough

`must_alloc` calls `calloc(1, nbytes)`. The `Optional` return models C's NULL. On failure it calls `abort`, because a C ABI `nif_init` cannot return a Mojo error and a null `ErlNifEntry*` is not a supported success path. `abort` is an undefined symbol from libSystem, resolved the same way as `enif_*` only if the main executable exports it; libSystem is a direct dependency, so `abort` is a normal dyld bind against `libSystem.B.dylib`, not against `beam.smp`. `nm -u` lists both. `otool -L` shows libSystem as a real dependent library, unlike the `enif_*` symbols which have no install name.

`slot[] = NifFunc(...)` writes a full struct through the calloc'd pointer. The thin function field copies the code pointer, not a pointer to a stack slot (see chapter 03).

## Under the hood

String literals are in the Mach-O image. Their origin is `ImmStaticOrigin`. As long as the `.so` stays mapped, the `name` fields are valid. `dlclose` on unload would invalidate them. OTP's refusal to reload is what currently keeps that hypothetical from running. Do not "fix" that by caching the `.so` yourself and unloading it.

Mojo `String` is length-prefixed and may move when it grows. Nothing in the NIF constructs one on the hot path. `String(unsafe_from_utf8_ptr=...)` appears only in experiments that print a literal back.

## Failure modes

- Returning `Pointer(to=local_struct)` from `nif_init`. The entry would point at a dead stack. `calloc` is the replacement.
- Freeing the entry at the end of `nif_init`. The VM uses it after the function returns.
- Building an Erlang binary that points at Mojo stack memory. Not done here; do not add it without an API that copies or that transfers ownership explicitly.
- Assuming the concurrent test blesses `parallelize` inside the NIF. It does not. `parallelize` was not called.

## Rustler and Zigler

Rustler resource types tie a Rust destructor to an Erlang resource, and the Rustler docs tell you not to keep `Env` or term pointers. Zigler generates allocators that go through `enif_alloc` when the memory should be visible to the VM, and uses its own allocator only with an explicit free. Mojoler uses `calloc` for two structs the VM does not free, and uses no resource type. That is a smaller feature set, not a stricter one.

## Checkpoint

1. When does `argv` become invalid? When `add` returns.
2. Who frees the `ErlNifEntry` block? Nobody, until the OS reaps the process.
3. Stretch: implement an unload callback in a copy of the experiment that frees both blocks, then load and unload in a short-lived VM. Do not replace `native/poc.mojo` until that experiment has a log.
