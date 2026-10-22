defmodule Mojoler.Nif do
  @moduledoc """
  Path and load bookkeeping. `:erlang.load_nif/2` must be called from the
  module named in the NIF entry. This module does not call it.
  """

  def path(stem) when is_binary(stem) do
    :mojoler
    |> Application.app_dir("priv/native/" <> stem)
    |> String.to_charlist()
  end

  def mark!(stem) when is_binary(stem) do
    :persistent_term.put({:mojoler_loaded, stem <> ".so"}, true)
    :ok
  end

  def loaded?(basename) when is_binary(basename) do
    :persistent_term.get({:mojoler_loaded, basename}, false)
  end
end
