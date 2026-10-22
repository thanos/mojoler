defmodule Consumer do
  @moduledoc """
  External app. It does not compile Mojo itself. The path dependency's Mix
  compiler does.
  """

  def add(a, b), do: Mojoler.POC.add(a, b)
end