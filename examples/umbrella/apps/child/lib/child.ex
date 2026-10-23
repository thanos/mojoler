defmodule Child do
  @moduledoc """
  Umbrella child that calls Mojoler.

  The child has no NIF of its own. `Mojoler.POC.add/2` and
  `Mojoler.Twice.double/1` load from the path dependency.
  """
end
