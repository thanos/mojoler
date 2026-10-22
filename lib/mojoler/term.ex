defmodule Mojoler.Term do
  @moduledoc """
  Checked conversions. Bad arguments are `ArgumentError`. Domain failures are
  `{:error, reason}` with a fixed atom vocabulary.

  `copy_binary/1` copies the payload and returns `{:ok, binary, copied_bytes}`.
  `borrow_stable/1` inspects a binary twice and returns `{:ok, size, 1}` when
  both views share one data pointer. `fill_output/1` writes into the binary
  OTP allocated for the return value.
  """

  @on_load :load_nif

  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libterm"), 0) do
      :ok -> Mojoler.Nif.mark!("libterm")
      other -> other
    end
  end

  def echo_i64(_), do: :erlang.nif_error(:nif_not_loaded)
  def echo_u64(_), do: :erlang.nif_error(:nif_not_loaded)
  def echo_i32(_), do: :erlang.nif_error(:nif_not_loaded)
  def echo_u32(_), do: :erlang.nif_error(:nif_not_loaded)
  def add_i64(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def echo_f64(_), do: :erlang.nif_error(:nif_not_loaded)
  def echo_atom(_), do: :erlang.nif_error(:nif_not_loaded)
  def copy_binary(_), do: :erlang.nif_error(:nif_not_loaded)
  def borrow_stable(_), do: :erlang.nif_error(:nif_not_loaded)
  def fill_output(_), do: :erlang.nif_error(:nif_not_loaded)
  def text_len(_), do: :erlang.nif_error(:nif_not_loaded)
  def tuple_sum(_), do: :erlang.nif_error(:nif_not_loaded)
  def list_sum(_), do: :erlang.nif_error(:nif_not_loaded)
  def map_n(_), do: :erlang.nif_error(:nif_not_loaded)
end
