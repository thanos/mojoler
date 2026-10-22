defmodule Mojoler.Sched do
  @moduledoc """
  Scheduler jobs. `burn/1` and `hold/2` run on a dirty CPU scheduler.
  `io_ping/0` runs on a dirty I/O scheduler.

  An Elixir timeout does not stop either job. `Task.yield/2` returning nil
  means the caller stopped waiting. The native loop runs until it finishes.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libsched"), 0) do
      :ok -> Mojoler.Nif.mark!("libsched")
      other -> other
    end
  end

  def burn(_), do: :erlang.nif_error(:nif_not_loaded)
  def hold(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def io_ping, do: :erlang.nif_error(:nif_not_loaded)
end
