defmodule Mojoler.Dsl.Box do
  @moduledoc """
  A generated resource whose step function is `native/examples/box_user.mojo`.

  `open/0` returns an opaque reference. The native object holds one signed
  integer, starting at 0. That field is not visible to Elixir.
  """

  @typedoc """
  Opaque box handle. Inspects as a reference. The running total is native state.
  """
  @type box :: reference()

  @on_load :load_nif

  @doc """
  Loads `priv/native/libdsl_box.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Dsl.Box.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_box"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_box")
      other -> other
    end
  end

  @doc """
  Opens a box whose total is 0.

  ## Returns

  A `t:box/0`.

  ## Examples

      iex> box = Mojoler.Dsl.Box.open()
      iex> is_reference(box)
      true

  """
  @spec open() :: box()
  # coveralls-ignore-next-line
  def open, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds `delta` to the box and returns the new total.

  `box` is a handle from `open/0`. `delta` is a signed integer. There is no
  optional argument. The native step is `value + delta`.

  ## Raises

    * `ArgumentError` when `box` is not a box from this module, or `delta`
      is not an integer

  ## Examples

      iex> box = Mojoler.Dsl.Box.open()
      iex> Mojoler.Dsl.Box.bump(box, 20)
      20
      iex> Mojoler.Dsl.Box.bump(box, 22)
      42
      iex> Mojoler.Dsl.Box.bump(:nope, 1)
      ** (ArgumentError) argument error

  """
  @spec bump(box(), integer()) :: integer()
  # coveralls-ignore-next-line
  def bump(_box, _delta), do: :erlang.nif_error(:nif_not_loaded)
end
