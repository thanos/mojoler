defmodule Mojoler.Dsl.Arith do
  @moduledoc """
  Checked addition generated from `tools/dsl/decls.json`.

  The native wrapper decodes the terms and calls `checked_add` in
  `native/examples/arith_user.mojo`. This module does not declare the NIF entry.
  """

  @on_load :load_nif

  @doc """
  Loads `priv/native/libdsl_arith.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Dsl.Arith.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_arith"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_arith")
      other -> other
    end
  end

  @doc """
  Adds `a` and `b` as signed 64-bit integers.

  Both arguments are required integers. There is no optional argument.

  ## Returns

    * `{:ok, sum}` when the sum fits
    * `{:error, :overflow}` when it does not

  ## Raises

    * `ArgumentError` when `a` or `b` is not an integer in signed 64 bits

  ## Examples

      iex> Mojoler.Dsl.Arith.add(20, 22)
      {:ok, 42}

      iex> Mojoler.Dsl.Arith.add(9_223_372_036_854_775_807, 1)
      {:error, :overflow}

      iex> Mojoler.Dsl.Arith.add(1, :nope)
      ** (ArgumentError) argument error

  """
  @spec add(integer(), integer()) :: {:ok, integer()} | {:error, :overflow}
  # coveralls-ignore-next-line
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
