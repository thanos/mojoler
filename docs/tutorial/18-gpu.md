# Unit 18 — GPU internals and ownership

## Objectives

Reproduce the one-element proof, then the four-element batch, and label what was not run.

## Why

A green CPU test cannot stand in for a device. A missing device must not be turned into a silent CPU success.

## Model

```text
host buffer -> enqueue_copy -> device buffer -> kernel -> copy back -> synchronize
historical     vector_size 1, result 42, experiments/gpu/gpu_nif.mojo (unchanged)
batch          vector_size 4, sum 110, experiments/gpu/batch_nif.mojo
no device      {:error, :no_device}     not observed on this Mac
```

## Theory

`std.gpu` is not in this stdlib. The kernel is `max.gpu`, pinned by `requirements-gpu.txt`. The callback calls `initialize_runtime()` and then `DeviceContext`. The batch NIF is registered with `abi_dirty_cpu()` because `synchronize` waits.

The numbers are constants in the Mojo file: left `1,2,3,4`, right `10,20,30,40`. The Elixir oracle is their pairwise sum, `110`. Two calls returned 110. Two overlapping tasks returned `[110, 110]`.

The host pointer is not treated as device memory. The code enqueue-copies into a device buffer and copies back. Buffers are local to the callback and dropped after `synchronize`, so a timeout cannot leave a caller holding a device pointer. There is no async GPU job that outlives the callback.

Linux GPU and NVIDIA were not run. The workflow does not install MAX.

## Lab

```sh
uv pip install -r requirements-gpu.txt
scripts/gpu-batch.sh
```

Skip the install if `.venv` already imports `max`. If the build fails, the script exits 2.

## Expected

`gpu_nif 42`, `gpu_batch 110`, `gpu_batch_repeat 110`, and `gpu_batch_concurrent [110, 110]`.

## Code

`experiments/gpu/batch_nif.mojo` `vector_addition` uses `block_idx` and `thread_idx` with `block_dim=4`. `experiments/gpu/gpu_nif.mojo` is the one-thread historical file. Do not edit it to add the batch.

## Failure

A machine without a GPU should print `{:error, :no_device}` from the batch NIF if the library loaded and `has_accelerator()` is false. That branch was not taken here. If you only see a CPU sum with no tag, the test is wrong: this file returns the error tuple instead.

## Exercise

Why is the batch on a dirty CPU scheduler?

## Answer

The callback blocks in `ctx.synchronize()`. Dirty CPU is the Stage 4 flag for a wait that would otherwise occupy a normal scheduler. It is not a measurement that the GPU driver itself is fair. The flag is `abi_dirty_cpu()`.
