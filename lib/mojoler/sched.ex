defmodule Mojoler.Sched do
  @moduledoc """
  Scheduler jobs.

  `burn/1` and `hold/2` run on a dirty CPU scheduler. `io_ping/0` runs on a
  dirty I/O scheduler. An Elixir timeout does not cancel the native work.
  `Task.yield/2` returning `nil` means the caller stopped waiting. The native
  function runs until it returns.
  """

  @on_load :load_nif

  @doc """
  Loads `priv/native/libsched.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Sched.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libsched"), 0) do
      :ok -> Mojoler.Nif.mark!("libsched")
      other -> other
    end
  end

  @doc """
  Spins for `milliseconds` on a dirty CPU scheduler, then returns `:ok`.

  `milliseconds` is an integer greater than or equal to 0. The loop reads the
  monotonic clock. A caller timeout does not stop it.

  ## Raises

    * `ArgumentError` when `milliseconds` is not an integer, or is negative

  ## Examples

      iex> Mojoler.Sched.burn(0)
      :ok

      iex> Mojoler.Sched.burn(-1)
      ** (ArgumentError) argument error

  """
  @spec burn(non_neg_integer()) :: :ok
  # coveralls-ignore-next-line
  def burn(_milliseconds), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Copies `bin`, spins for `milliseconds`, and returns the same bytes.

  The borrowed view of `bin` is released before the spin. The loop reads the
  copy. `milliseconds` is an integer greater than or equal to 0.

  ## Returns

  The copied binary.

  ## Raises

    * `ArgumentError` when `bin` is not a binary, or `milliseconds` is not
      an integer greater than or equal to 0

  ## Examples

      iex> Mojoler.Sched.hold(<<1, 2, 3>>, 0)
      <<1, 2, 3>>

      iex> Mojoler.Sched.hold(<<1::7>>, 0)
      ** (ArgumentError) argument error

  """
  @spec hold(binary(), non_neg_integer()) :: binary()
  # coveralls-ignore-next-line
  def hold(_bin, _milliseconds), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `:ok` from a dirty I/O scheduler.

  There are no arguments.

  ## Examples

      iex> Mojoler.Sched.io_ping()
      :ok

  """
  @spec io_ping() :: :ok
  # coveralls-ignore-next-line
  def io_ping, do: :erlang.nif_error(:nif_not_loaded)
end
