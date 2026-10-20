defmodule Mojoler.POC do
  @moduledoc """
  Proof-of-concept NIF. `add/2` is implemented in `native/poc.mojo`.

  The BEAM module name is `Elixir.Mojoler.POC`. That string is what
  `nif_init` writes into `ErlNifEntry.name`.
  """

  @on_load :load_nif

  def load_nif do
    path =
      :mojoler
      |> Application.app_dir("priv/native/libpoc")
      |> String.to_charlist()

    :erlang.load_nif(path, 0)
  end

  @doc """
  Checked Int64 addition.

  Integers that do not fit in signed 64 bits, non-integers, and sums that
  would overflow signed 64 bits become `ArgumentError`.
  """
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc false
  def reload, do: load_nif()
end
