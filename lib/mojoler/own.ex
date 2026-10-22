defmodule Mojoler.Own do
  @moduledoc """
  Resource ownership. A counter is synchronized and closeable. A blob copies
  its input, tracks borrows, and freezes into a resource binary. A retained
  binary lives in an env that outlasts the calling process.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libown"), 0) do
      :ok -> Mojoler.Nif.mark!("libown")
      other -> other
    end
  end

  def open_counter, do: :erlang.nif_error(:nif_not_loaded)
  def counter_add(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def counter_close(_), do: :erlang.nif_error(:nif_not_loaded)
  def open_blob(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_borrow(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_release(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_freeze(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_close(_), do: :erlang.nif_error(:nif_not_loaded)
  def retain_binary(_), do: :erlang.nif_error(:nif_not_loaded)
  def read_retained(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_token(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_poke(_, _, _), do: :erlang.nif_error(:nif_not_loaded)
  def blob_pin(_), do: :erlang.nif_error(:nif_not_loaded)
  def blob_dtors, do: :erlang.nif_error(:nif_not_loaded)
end
