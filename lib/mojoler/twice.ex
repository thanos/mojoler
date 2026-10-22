defmodule Mojoler.Twice do
  @moduledoc """
  Second NIF. `double/1` uses the generated ABI module and does not redeclare
  `ErlNifFunc` or `ErlNifEntry`.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libtwice"), 0) do
      :ok -> Mojoler.Nif.mark!("libtwice")
      other -> other
    end
  end

  @doc """
  Checked `2 * n` for a signed 64-bit integer. Overflow is `ArgumentError`.
  """
  def double(_n), do: :erlang.nif_error(:nif_not_loaded)
end
