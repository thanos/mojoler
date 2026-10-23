defmodule Mojoler.POC do
  @moduledoc """
  Checked signed 64-bit addition, loaded from `priv/native/libpoc.so`.

  The entry name is `Elixir.Mojoler.POC`. `nif_init` writes that string
  into `ErlNifEntry.name`.
  """

  @typedoc """
  A signed 64-bit integer. Values outside this range are not terms this NIF accepts.
  """
  @type i64 :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @on_load :load_nif

  @doc """
  Loads `priv/native/libpoc.so`.

  Called from this module by `@on_load`. A second call in the same VM returns
  an error. The library stays loaded until the OS process exits.

  ## Returns

    * `:ok` on the first load
    * `{:error, {:reload, charlist}}` when OTP rejects a second load
    * `{:error, reason}` when the file is missing or the entry is refused

  ## Examples

      iex> Mojoler.POC.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libpoc"), 0) do
      :ok -> Mojoler.Nif.mark!("libpoc")
      other -> other
    end
  end

  @doc """
  Returns `a + b` when both arguments and the sum fit in a signed 64-bit integer.

  `a` and `b` are integers. Floats, atoms, and binaries are rejected.
  There is no optional argument.

  ## Returns

  The sum, an integer.

  ## Raises

    * `ArgumentError` when `a` or `b` is not an integer, does not fit in
      signed 64 bits, or the sum would overflow

  A wrong arity never reaches this function. Elixir raises `UndefinedFunctionError`.

  ## Examples

      iex> Mojoler.POC.add(20, 22)
      42

      iex> Mojoler.POC.add(-5, -7)
      -12

      iex> Mojoler.POC.add(1, :nope)
      ** (ArgumentError) argument error

      iex> Mojoler.POC.add(9_223_372_036_854_775_807, 1)
      ** (ArgumentError) argument error

  """
  @spec add(i64(), i64()) :: i64()
  # coveralls-ignore-next-line
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Loads the library again.

  Same contract as `load_nif/0`. The suite uses it to observe OTP's reload refusal.

  ## Examples

      iex> Mojoler.POC.reload()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec reload() :: :ok | {:error, term()}
  def reload, do: load_nif()
end
