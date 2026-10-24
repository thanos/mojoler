#!/usr/bin/env bash
# Reproduce the historical one-call GPU NIF, then the batched library.
# experiments/gpu/gpu_nif.mojo and add_host.mojo are not modified.
# Linux and NVIDIA are not run by this script. A missing MAX install is NOT RUN.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
mojo="$root/.venv/bin/mojo"

if ! "$mojo" build "$root/experiments/gpu/gpu_nif.mojo" \
  --emit shared-lib \
  -o "$root/experiments/gpu/libgpu.so" \
  "${MOJO_LINK_FLAGS[@]}"; then
  printf 'gpu: historical proof did not build. NOT RUN\n' >&2
  exit 2
fi

if ! "$mojo" build "$root/experiments/gpu/batch_nif.mojo" \
  --emit shared-lib \
  -I "$root/native" \
  -o "$root/experiments/gpu/libbatch.so" \
  "${MOJO_LINK_FLAGS[@]}"; then
  printf 'gpu: batch library did not build. NOT RUN\n' >&2
  exit 2
fi

elixir -e '
defmodule Mojoler.GPUProbe do
  def load(path), do: :erlang.load_nif(String.to_charlist(path), 0)
  def sum, do: :erlang.nif_error(:nif_not_loaded)
end
defmodule Mojoler.GPUBatch do
  def load(path), do: :erlang.load_nif(String.to_charlist(path), 0)
  def batch, do: :erlang.nif_error(:nif_not_loaded)
end
:ok = Mojoler.GPUProbe.load("'"$root"'/experiments/gpu/libgpu")
:ok = Mojoler.GPUBatch.load("'"$root"'/experiments/gpu/libbatch")
IO.puts("gpu_nif #{Mojoler.GPUProbe.sum()}")
IO.puts("gpu_batch #{inspect(Mojoler.GPUBatch.batch())}")
IO.puts("gpu_batch_repeat #{inspect(Mojoler.GPUBatch.batch())}")
tasks = for _ <- 1..2, do: Task.async(fn -> Mojoler.GPUBatch.batch() end)
IO.puts("gpu_batch_concurrent #{inspect(Task.await_many(tasks), charlists: :as_lists)}")
'
