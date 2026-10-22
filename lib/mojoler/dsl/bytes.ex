defmodule Mojoler.Dsl.Bytes do
  @moduledoc """
  Generated from `tools/dsl/decls.json`. User code is `examples.bytes_user`.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_bytes"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_bytes")
      other -> other
    end
  end

  def shift(_), do: :erlang.nif_error(:nif_not_loaded)
  def borrow_len(_), do: :erlang.nif_error(:nif_not_loaded)
end
