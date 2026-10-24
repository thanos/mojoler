defmodule Mojoler.Term do
  @moduledoc """
  Checked conversions between Elixir terms and Mojo values.

  A value of the wrong Elixir type, or an integer outside the declared width,
  raises `ArgumentError`. A value of the right shape that fails a domain rule
  returns `{:error, reason}`.

  `copy_binary/1` returns a new binary and the number of bytes copied.
  `borrow_stable/1` inspects one binary twice and reports whether the views
  share a data pointer. `fill_output/1` writes into a binary OTP allocated
  for the return value.
  """

  @typedoc """
  Signed 64-bit integer.
  """
  @type i64 :: -9_223_372_036_854_775_808..9_223_372_036_854_775_807

  @typedoc """
  Unsigned 64-bit integer.
  """
  @type u64 :: 0..18_446_744_073_709_551_615

  @typedoc """
  Signed 32-bit integer.
  """
  @type i32 :: -2_147_483_648..2_147_483_647

  @typedoc """
  Unsigned 32-bit integer.
  """
  @type u32 :: 0..4_294_967_295

  @typedoc """
  Atoms `echo_atom/1` returns unchanged.

  ## Examples

      :ok
      :error
      nil
      true
      false

  """
  @type atom_vocab :: :ok | :error | nil | true | false

  @typedoc """
  Domain errors from this module. Which ones a function can return is listed
  on that function.

    * `:overflow` — the arithmetic result does not fit in signed 64 bits
    * `:unknown_atom` — the atom is outside `t:atom_vocab/0`
    * `:not_binary` — the term is not a binary
    * `:too_large` — the binary is longer than 1_048_576 bytes
    * `:alloc` — OTP could not allocate the copy
    * `:bad_size` — the requested output size is not an integer in `0..1_048_576`
    * `:invalid_utf8` — the bytes are not UTF-8
    * `:not_tuple` — the term is not a tuple
    * `:bad_arity` — the tuple does not have two elements
    * `:bad_element` — an element is not a signed 64-bit integer
    * `:not_list` — the term is not a list
    * `:improper_list` — the list is improper
    * `:too_long` — the list has more than 64 elements
    * `:missing` — the map has no `:n` key
    * `:map` — OTP refused the one-key map built for the return value

  """
  @type error ::
          :overflow
          | :unknown_atom
          | :not_binary
          | :too_large
          | :alloc
          | :bad_size
          | :invalid_utf8
          | :not_tuple
          | :bad_arity
          | :bad_element
          | :not_list
          | :improper_list
          | :too_long
          | :missing
          | :map

  @on_load :load_nif

  @doc """
  Loads `priv/native/libterm.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Term.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libterm"), 0) do
      :ok -> Mojoler.Nif.mark!("libterm")
      other -> other
    end
  end

  @doc """
  Returns `n` when it fits in a signed 64-bit integer.

  ## Raises

    * `ArgumentError` when `n` is not an integer in `t:i64/0`

  ## Examples

      iex> Mojoler.Term.echo_i64(0)
      0

      iex> Mojoler.Term.echo_i64(-9_223_372_036_854_775_808)
      -9223372036854775808

      iex> Mojoler.Term.echo_i64(:nope)
      ** (ArgumentError) argument error

  """
  @spec echo_i64(i64()) :: i64()
  # coveralls-ignore-next-line
  def echo_i64(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `n` when it fits in an unsigned 64-bit integer.

  ## Raises

    * `ArgumentError` when `n` is not an integer in `t:u64/0`

  ## Examples

      iex> Mojoler.Term.echo_u64(0)
      0

      iex> Mojoler.Term.echo_u64(18_446_744_073_709_551_615)
      18446744073709551615

      iex> Mojoler.Term.echo_u64(-1)
      ** (ArgumentError) argument error

  """
  @spec echo_u64(u64()) :: u64()
  # coveralls-ignore-next-line
  def echo_u64(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `n` when it fits in a signed 32-bit integer.

  ## Raises

    * `ArgumentError` when `n` is not an integer in `t:i32/0`

  ## Examples

      iex> Mojoler.Term.echo_i32(-2_147_483_648)
      -2147483648

      iex> Mojoler.Term.echo_i32(2_147_483_648)
      ** (ArgumentError) argument error

  """
  @spec echo_i32(i32()) :: i32()
  # coveralls-ignore-next-line
  def echo_i32(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `n` when it fits in an unsigned 32-bit integer.

  ## Raises

    * `ArgumentError` when `n` is not an integer in `t:u32/0`

  ## Examples

      iex> Mojoler.Term.echo_u32(4_294_967_295)
      4294967295

      iex> Mojoler.Term.echo_u32(-1)
      ** (ArgumentError) argument error

  """
  @spec echo_u32(u32()) :: u32()
  # coveralls-ignore-next-line
  def echo_u32(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds two signed 64-bit integers.

  `a` and `b` must each fit in `t:i64/0`. There is no optional argument.

  ## Returns

    * `{:ok, sum}` when the sum fits
    * `{:error, :overflow}` when the sum does not fit

  ## Raises

    * `ArgumentError` when `a` or `b` is not an integer in `t:i64/0`

  ## Examples

      iex> Mojoler.Term.add_i64(20, 22)
      {:ok, 42}

      iex> Mojoler.Term.add_i64(9_223_372_036_854_775_807, 1)
      {:error, :overflow}

      iex> Mojoler.Term.add_i64(9_223_372_036_854_775_808, 0)
      ** (ArgumentError) argument error

  """
  @spec add_i64(i64(), i64()) :: {:ok, i64()} | {:error, :overflow}
  # coveralls-ignore-next-line
  def add_i64(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `n` when it is a finite float.

  Integers are not coerced. This OTP build does not construct non-finite floats,
  so that branch has no example here.

  ## Raises

    * `ArgumentError` when `n` is not a float

  ## Examples

      iex> Mojoler.Term.echo_f64(1.5)
      1.5

      iex> Mojoler.Term.echo_f64(0.0)
      0.0

      iex> Mojoler.Term.echo_f64(1)
      ** (ArgumentError) argument error

  """
  @spec echo_f64(float()) :: float()
  # coveralls-ignore-next-line
  def echo_f64(_n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `atom` when it is one of `t:atom_vocab/0`.

  ## Returns

    * the same atom, for `:ok`, `:error`, `nil`, `true`, or `false`
    * `{:error, :unknown_atom}` for any other atom

  ## Raises

    * `ArgumentError` when `atom` is not an atom

  ## Examples

      iex> Mojoler.Term.echo_atom(:ok)
      :ok

      iex> Mojoler.Term.echo_atom(nil)
      nil

      iex> Mojoler.Term.echo_atom(true)
      true

      iex> Mojoler.Term.echo_atom(:other)
      {:error, :unknown_atom}

  """
  @spec echo_atom(atom()) :: atom_vocab() | {:error, :unknown_atom}
  # coveralls-ignore-next-line
  def echo_atom(_atom), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Copies `bin` into a new binary.

  `bin` must be a binary of at most 1_048_576 bytes. A sub-binary copies only
  its own bytes. Bitstrings that are not binaries are refused.

  ## Returns

    * `{:ok, copy, nbytes}` where `nbytes` is `byte_size(copy)`
    * `{:error, :not_binary}`
    * `{:error, :too_large}`
    * `{:error, :alloc}` when OTP cannot allocate the copy

  ## Examples

      iex> Mojoler.Term.copy_binary(<<1, 2, 3>>)
      {:ok, <<1, 2, 3>>, 3}

      iex> Mojoler.Term.copy_binary(<<>>)
      {:ok, <<>>, 0}

      iex> Mojoler.Term.copy_binary(<<1::7>>)
      {:error, :not_binary}

  """
  @spec copy_binary(binary()) ::
          {:ok, binary(), non_neg_integer()} | {:error, :not_binary | :too_large | :alloc}
  # coveralls-ignore-next-line
  def copy_binary(_bin), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Inspects `bin` twice and reports whether both views use one data pointer.

  The pointer is freed before this function returns. Elixir receives the size
  and a flag, not an address.

  ## Returns

    * `{:ok, size, 1}` when the two views share a data pointer
    * `{:ok, size, 0}` when they do not
    * `{:error, :not_binary}`

  ## Examples

      iex> Mojoler.Term.borrow_stable(<<1, 2, 3>>)
      {:ok, 3, 1}

      iex> Mojoler.Term.borrow_stable(<<1::7>>)
      {:error, :not_binary}

  """
  @spec borrow_stable(binary()) ::
          {:ok, non_neg_integer(), 0 | 1} | {:error, :not_binary}
  # coveralls-ignore-next-line
  def borrow_stable(_bin), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns a new binary of `nbytes` bytes, each set to 7.

  `nbytes` is an integer in `0..1_048_576`. OTP allocates the binary. Mojo
  fills it. There is no earlier payload buffer.

  ## Returns

    * `{:ok, binary}`
    * `{:error, :bad_size}` when `nbytes` is not an integer in that range

  ## Examples

      iex> Mojoler.Term.fill_output(4)
      {:ok, <<7, 7, 7, 7>>}

      iex> Mojoler.Term.fill_output(0)
      {:ok, <<>>}

      iex> Mojoler.Term.fill_output(-1)
      {:error, :bad_size}

      iex> Mojoler.Term.fill_output(:nope)
      {:error, :bad_size}

  """
  @spec fill_output(non_neg_integer()) :: {:ok, binary()} | {:error, :bad_size}
  # coveralls-ignore-next-line
  def fill_output(_nbytes), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the byte size of `bin` when the bytes are UTF-8.

  The check does not normalize. An empty binary is valid UTF-8 of length 0.

  ## Returns

    * `{:ok, byte_size}`
    * `{:error, :not_binary}`
    * `{:error, :invalid_utf8}`

  ## Examples

      iex> Mojoler.Term.text_len("héllo")
      {:ok, 6}

      iex> Mojoler.Term.text_len(<<>>)
      {:ok, 0}

      iex> Mojoler.Term.text_len(<<0xFF>>)
      {:error, :invalid_utf8}

      iex> Mojoler.Term.text_len([1])
      {:error, :not_binary}

  """
  @spec text_len(binary()) :: {:ok, non_neg_integer()} | {:error, :not_binary | :invalid_utf8}
  # coveralls-ignore-next-line
  def text_len(_bin), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds the two integers in `tuple`.

  `tuple` must be a 2-tuple of signed 64-bit integers.

  ## Returns

    * `{:ok, sum}`
    * `{:error, :not_tuple}`
    * `{:error, :bad_arity}`
    * `{:error, :bad_element}`
    * `{:error, :overflow}`

  ## Examples

      iex> Mojoler.Term.tuple_sum({20, 22})
      {:ok, 42}

      iex> Mojoler.Term.tuple_sum({1})
      {:error, :bad_arity}

      iex> Mojoler.Term.tuple_sum({1, :a})
      {:error, :bad_element}

      iex> Mojoler.Term.tuple_sum([1, 2])
      {:error, :not_tuple}

  """
  @spec tuple_sum(tuple()) ::
          {:ok, i64()} | {:error, :not_tuple | :bad_arity | :bad_element | :overflow}
  # coveralls-ignore-next-line
  def tuple_sum(_tuple), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds the integers in `list`.

  `list` must be a proper list of at most 64 signed 64-bit integers.
  Nested lists are a bad element, not a recursive sum.

  ## Returns

    * `{:ok, sum}`
    * `{:error, :not_list}`
    * `{:error, :improper_list}`
    * `{:error, :too_long}`
    * `{:error, :bad_element}`
    * `{:error, :overflow}`

  ## Examples

      iex> Mojoler.Term.list_sum([20, 22, 19, 25])
      {:ok, 86}

      iex> Mojoler.Term.list_sum([1 | 2])
      {:error, :improper_list}

      iex> Mojoler.Term.list_sum([[1]])
      {:error, :bad_element}

      iex> Mojoler.Term.list_sum(Enum.to_list(1..65))
      {:error, :too_long}

  """
  @spec list_sum(list()) ::
          {:ok, i64()}
          | {:error, :not_list | :improper_list | :too_long | :bad_element | :overflow}
  # coveralls-ignore-next-line
  def list_sum(_list), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns `%{n: n}` when `map` contains an integer under the key `:n`.

  Extra keys are dropped. A missing key and a non-integer value are errors.

  ## Returns

    * `{:ok, %{n: integer}}`
    * `{:error, :missing}` when `:n` is absent, including when `map` is not a map
    * `{:error, :bad_element}` when `:n` is not a signed 64-bit integer
    * `{:error, :map}` when OTP refuses the returned map

  ## Examples

      iex> Mojoler.Term.map_n(%{n: 7})
      {:ok, %{n: 7}}

      iex> Mojoler.Term.map_n(%{n: 7, extra: 1})
      {:ok, %{n: 7}}

      iex> Mojoler.Term.map_n(%{})
      {:error, :missing}

      iex> Mojoler.Term.map_n(%{n: :a})
      {:error, :bad_element}

  """
  @spec map_n(map()) :: {:ok, %{n: i64()}} | {:error, :missing | :bad_element | :map}
  # coveralls-ignore-next-line
  def map_n(_map), do: :erlang.nif_error(:nif_not_loaded)
end
