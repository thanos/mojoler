# One-scheduler heartbeat probe.
#   elixir --erl "+S 1" experiments/sched/measure.exs MODE PATH
# Prints "beats N elapsed MS".

[mode, path] = System.argv()

case mode do
  "dirty" ->
    defmodule Mojoler.Sched do
      def load(nif_path), do: :erlang.load_nif(String.to_charlist(nif_path), 0)
      def burn(_ms), do: :erlang.nif_error(:nif_not_loaded)
      def hold(_bin, _ms), do: :erlang.nif_error(:nif_not_loaded)
      def io_ping, do: :erlang.nif_error(:nif_not_loaded)
    end

  "normal" ->
    defmodule Mojoler.Normal do
      def load(nif_path), do: :erlang.load_nif(String.to_charlist(nif_path), 0)
      def burn(_ms), do: :erlang.nif_error(:nif_not_loaded)
    end
end

module =
  case mode do
    "dirty" -> Mojoler.Sched
    "normal" -> Mojoler.Normal
  end

:ok = module.load(path)
parent = self()

heartbeat =
  spawn(fn ->
    Enum.each(1..100, fn _ ->
      Process.sleep(10)
      send(parent, :beat)
    end)
  end)

receive do
  :beat -> :ok
after
  1_000 ->
    IO.puts(:stderr, "heartbeat did not start")
    System.halt(1)
end

receive do
  :beat -> :ok
after
  0 -> :ok
end

started = System.monotonic_time(:millisecond)
:ok = module.burn(200)
elapsed = System.monotonic_time(:millisecond) - started

beats =
  Enum.reduce(1..100, 0, fn _, count ->
    receive do
      :beat -> count + 1
    after
      0 -> count
    end
  end)

Process.exit(heartbeat, :kill)
IO.puts("beats #{beats} elapsed #{elapsed}")
