#!/usr/bin/env bash
# Correctness oracles and separated timings. This script does not claim that
# add/2 is faster than Elixir.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

mix run --no-start -e '
oracle = Mojoler.POC.add(20, 22)
IO.puts("oracle #{oracle}")

copy = Mojoler.Term.copy_binary(<<1, 2, 3>>)
borrow = Mojoler.Term.borrow_stable(:binary.copy(<<1>>, 32))
filled = Mojoler.Term.fill_output(4)
IO.puts("copy #{inspect(copy)}")
IO.puts("borrow #{inspect(borrow)}")
IO.puts("filled #{inspect(filled)}")

blob = Mojoler.Own.open_blob(<<9, 9>>)
{:ok, token} = Mojoler.Own.blob_token(blob)
:ok = Mojoler.Own.blob_poke(blob, 0, 4)
{:ok, frozen} = Mojoler.Own.blob_freeze(blob)
IO.puts("frozen #{inspect(frozen)} token #{token}")

parent = self()
spawn(fn -> send(parent, Mojoler.Own.retain_binary(<<7, 7>>)) end)
handle = receive do h -> h end
IO.puts("retained #{inspect(Mojoler.Own.read_retained(handle))}")

started = System.monotonic_time(:microsecond)
:ok = Mojoler.Sched.burn(50)
burned = System.monotonic_time(:microsecond) - started
IO.puts("dirty_burn_us #{burned}")

warm0 = System.monotonic_time(:microsecond)
_ = Mojoler.POC.add(1, 1)
warm = System.monotonic_time(:microsecond) - warm0
IO.puts("warm_add_us #{warm}")
'
