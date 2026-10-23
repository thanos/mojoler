defmodule Consumer do
  @moduledoc """
  Sample application that depends on Mojoler.

  This app does not compile Mojo. The path dependency's Mix compiler builds
  the NIFs when this project compiles.
  """

  @doc """
  Returns `a + b` through `Mojoler.POC.add/2`.

  `a` and `b` are signed 64-bit integers. The overflow and type rules are
  the ones on `Mojoler.POC.add/2`.

  ## Examples

      iex> Consumer.add(20, 22)
      42

      iex> Consumer.add(1, :nope)
      ** (ArgumentError) argument error

  """
  @spec add(integer(), integer()) :: integer()
  def add(a, b), do: Mojoler.POC.add(a, b)
end
