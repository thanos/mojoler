defmodule Mojoler.Dsl.Arith do
  @moduledoc """
  Generated from `tools/dsl/decls.json`. User code is `examples.arith_user`.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_arith"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_arith")
      other -> other
    end
  end

  def add(_, _), do: :erlang.nif_error(:nif_not_loaded)
end
