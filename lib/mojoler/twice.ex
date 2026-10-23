defmodule Mojoler.Twice do
  @moduledoc """
  Checked doubling of a signed 64-bit integer, loaded from `priv/native/libtwice.so`.

  The native file imports the generated ABI. It does not declare `ErlNifFunc`
  or `ErlNifEntry`.
  """

  @typedoc """
  A signed 64-bit integer.
  """
  @type i64 :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @on_load :load_nif

  @doc """
  Loads `priv/native/libtwice.so`.

  A second call in the same VM returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Twice.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libtwice"), 0) do
      :ok -> Mojoler.Nif.mark!("libtwice")
      other -> other
    end
  end

  @doc """
  Returns `2 * n` when `n` and the product fit in a signed 64-bit integer.

  `n` is an integer. There is no optional argument.

  ## Returns

  The product, an integer.

  ## Raises

    * `ArgumentError` when `n` is not an integer, does not fit in signed 64 bits,
      or `2 * n` would overflow

  ## Examples

      iex> Mojoler.Twice.double(21)
      42

      iex> Mojoler.Twice.double(0)
      0

      iex> Mojoler.Twice.double(-3)
      -6

      iex> Mojoler.Twice.double(:nope)
      ** (ArgumentError) argument error

      iex> Mojoler.Twice.double(9_223_372_036_854_775_807)
      ** (ArgumentError) argument error

  """
  @spec double(i64()) :: i64()
  # coveralls-ignore-next-line
  def double(_n), do: :erlang.nif_error(:nif_not_loaded)
end
