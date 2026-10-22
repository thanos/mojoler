defmodule Mojoler.Dsl.Box do
  @moduledoc """
  Generated from `tools/dsl/decls.json`. User code is `examples.box_user`.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_box"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_box")
      other -> other
    end
  end

  def open, do: :erlang.nif_error(:nif_not_loaded)
  def bump(_, _), do: :erlang.nif_error(:nif_not_loaded)
end
