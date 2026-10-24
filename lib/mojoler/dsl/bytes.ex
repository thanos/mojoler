defmodule Mojoler.Dsl.Bytes do
  @moduledoc """
  Binary examples generated from `tools/dsl/decls.json`.

  `shift/1` copies the payload and adds 1 to each byte, wrapping at 255.
  `borrow_len/1` reads the size of the caller's binary and does not copy it.
  The byte function lives in `native/examples/bytes_user.mojo`.
  """

  @on_load :load_nif

  @doc """
  Loads `priv/native/libdsl_bytes.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Dsl.Bytes.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libdsl_bytes"), 0) do
      :ok -> Mojoler.Nif.mark!("libdsl_bytes")
      other -> other
    end
  end

  @doc """
  Returns a copy of `bin` with each byte increased by 1, modulo 256.

  `bin` must be a binary. A bitstring that is not a binary is an error.

  ## Returns

    * `{:ok, shifted, nbytes}` where `nbytes` is the byte size
    * `{:error, :not_binary}`

  ## Examples

      iex> Mojoler.Dsl.Bytes.shift(<<1, 2, 255>>)
      {:ok, <<2, 3, 0>>, 3}

      iex> Mojoler.Dsl.Bytes.shift(<<>>)
      {:ok, <<>>, 0}

      iex> Mojoler.Dsl.Bytes.shift([1, 2])
      {:error, :not_binary}

  """
  @spec shift(binary()) :: {:ok, binary(), non_neg_integer()} | {:error, :not_binary}
  # coveralls-ignore-next-line
  def shift(_bin), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the byte size of `bin` without copying the payload.

  ## Returns

    * `{:ok, size}`
    * `{:error, :not_binary}` for a list or a bitstring that is not a binary

  ## Examples

      iex> Mojoler.Dsl.Bytes.borrow_len(<<1, 2, 3, 4>>)
      {:ok, 4}

      iex> Mojoler.Dsl.Bytes.borrow_len(<<1::7>>)
      {:error, :not_binary}

  """
  @spec borrow_len(binary()) :: {:ok, non_neg_integer()} | {:error, :not_binary}
  # coveralls-ignore-next-line
  def borrow_len(_bin), do: :erlang.nif_error(:nif_not_loaded)
end
