defmodule Mojoler.Own do
  @moduledoc """
  Resource ownership for counters, blobs, pins, and retained terms.

  A counter is a mutex-protected integer. Closing it is idempotent. When the
  VM collects the resource, the destructor sends `:counter_destroyed` once
  to the process that created it.

  A blob is a copy of a binary. Borrowing it blocks freeze. Freeze publishes
  the bytes as a resource binary. A pin keeps the blob alive after the
  original handle is dropped. A retained term is a copy in a private
  environment and remains readable after the creating process exits.

  Handles are opaque references. The native fields (value, borrow count,
  token, buffer pointer) are not Elixir fields.

  Examples that create a handle store it in `:persistent_term` under a
  private key. That keeps the destructor from running while later examples
  in this VM still hold a use for the same object. A program that is finished
  with a handle drops it and lets the VM collect it.
  """

  @typedoc """
  Opaque counter handle returned by `open_counter/0`.

  Inspects as a reference. It has no Elixir-visible fields.

  ## Examples

      iex> counter = Mojoler.Own.open_counter()
      iex> :persistent_term.put(:mojoler_doc_counter_type, counter)
      iex> is_reference(counter)
      true

  """
  @type counter :: reference()

  @typedoc """
  Opaque blob handle returned by `open_blob/1`.

  Inspects as a reference. The copied bytes, borrow count, closed flag,
  frozen flag, and token live in the native object.
  """
  @type blob :: reference()

  @typedoc """
  Opaque pin returned by `blob_pin/1`.

  While this reference is alive, the pinned blob's destructor does not run.
  """
  @type pin :: reference()

  @typedoc """
  Opaque handle returned by `retain_binary/1`.

  `read_retained/1` copies the stored term back out.
  """
  @type retained :: reference()

  @on_load :load_nif

  @doc """
  Loads `priv/native/libown.so`.

  A second call returns `{:error, {:reload, charlist}}`.

  ## Examples

      iex> Mojoler.Own.load_nif()
      {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}}

  """
  @spec load_nif() :: :ok | {:error, term()}
  def load_nif do
    case :erlang.load_nif(Mojoler.Nif.path("libown"), 0) do
      :ok -> Mojoler.Nif.mark!("libown")
      other -> other
    end
  end

  @doc """
  Opens a counter at 0.

  ## Returns

  A `t:counter/0`.

  ## Examples

      iex> counter = Mojoler.Own.open_counter()
      iex> :persistent_term.put(:mojoler_doc_open_counter, counter)
      iex> Mojoler.Own.counter_add(counter, 0)
      {:ok, 0}

  """
  @spec open_counter() :: counter()
  # coveralls-ignore-next-line
  def open_counter, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Adds `n` to `counter` and returns the new total.

  `counter` is a `t:counter/0`. `n` is a signed 64-bit integer. There is no
  optional argument.

  ## Returns

    * `{:ok, total}`
    * `{:error, :closed}` after `counter_close/1`

  ## Raises

    * `ArgumentError` when `counter` is not a counter from this module, or
      `n` is not an integer

  ## Examples

      iex> counter = Mojoler.Own.open_counter()
      iex> :persistent_term.put(:mojoler_doc_counter_add, counter)
      iex> Mojoler.Own.counter_add(counter, 20)
      {:ok, 20}
      iex> Mojoler.Own.counter_add(counter, 22)
      {:ok, 42}
      iex> Mojoler.Own.counter_add(:nope, 1)
      ** (ArgumentError) argument error

  """
  @spec counter_add(counter(), integer()) :: {:ok, integer()} | {:error, :closed}
  # coveralls-ignore-next-line
  def counter_add(_counter, _n), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Marks `counter` closed.

  A second close on the same handle returns `:ok`. Further adds return
  `{:error, :closed}`.

  ## Raises

    * `ArgumentError` when `counter` is not a counter from this module

  ## Examples

      iex> counter = Mojoler.Own.open_counter()
      iex> :persistent_term.put(:mojoler_doc_counter_close, counter)
      iex> Mojoler.Own.counter_close(counter)
      :ok
      iex> Mojoler.Own.counter_close(counter)
      :ok
      iex> Mojoler.Own.counter_add(counter, 1)
      {:error, :closed}

  """
  @spec counter_close(counter()) :: :ok
  # coveralls-ignore-next-line
  def counter_close(_counter), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Copies `bin` into a new blob.

  ## Returns

    * a `t:blob/0`
    * `{:error, :not_binary}` when `bin` is not a binary

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
      iex> :persistent_term.put(:mojoler_doc_open_blob, blob)
      iex> is_reference(blob)
      true
      iex> Mojoler.Own.open_blob([1, 2, 3])
      {:error, :not_binary}

  """
  @spec open_blob(binary()) :: blob() | {:error, :not_binary}
  # coveralls-ignore-next-line
  def open_blob(_bin), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Increments the borrow count and returns the byte size.

  Freeze is refused while the count is above zero.

  ## Returns

    * `{:ok, size}`
    * `{:error, :not_mutable}` when the blob is closed or frozen

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
      iex> :persistent_term.put(:mojoler_doc_blob_borrow, blob)
      iex> Mojoler.Own.blob_borrow(blob)
      {:ok, 3}
      iex> Mojoler.Own.blob_release(blob)
      :ok

  """
  @spec blob_borrow(blob()) :: {:ok, non_neg_integer()} | {:error, :not_mutable}
  # coveralls-ignore-next-line
  def blob_borrow(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Decrements the borrow count when it is above zero.

  A release with no outstanding borrow still returns `:ok`.

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1>>)
      iex> :persistent_term.put(:mojoler_doc_blob_release, blob)
      iex> Mojoler.Own.blob_borrow(blob)
      {:ok, 1}
      iex> Mojoler.Own.blob_release(blob)
      :ok
      iex> Mojoler.Own.blob_release(blob)
      :ok

  """
  @spec blob_release(blob()) :: :ok
  # coveralls-ignore-next-line
  def blob_release(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Publishes the blob bytes as a resource binary.

  The returned binary stays valid after `blob_close/1`. A later poke returns
  `{:error, :not_mutable}`.

  ## Returns

    * `{:ok, binary}`
    * `{:error, :borrowed}` while a borrow is outstanding
    * `{:error, :frozen}` when the blob was already frozen

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
      iex> :persistent_term.put(:mojoler_doc_blob_freeze, blob)
      iex> Mojoler.Own.blob_borrow(blob)
      {:ok, 3}
      iex> Mojoler.Own.blob_freeze(blob)
      {:error, :borrowed}
      iex> Mojoler.Own.blob_release(blob)
      :ok
      iex> Mojoler.Own.blob_freeze(blob)
      {:ok, <<1, 2, 3>>}
      iex> Mojoler.Own.blob_freeze(blob)
      {:error, :frozen}

  """
  @spec blob_freeze(blob()) :: {:ok, binary()} | {:error, :borrowed | :frozen}
  # coveralls-ignore-next-line
  def blob_freeze(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Marks `blob` closed.

  Close does not invalidate a binary already returned by `blob_freeze/1`.

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
      iex> :persistent_term.put(:mojoler_doc_blob_close, blob)
      iex> {:ok, bin} = Mojoler.Own.blob_freeze(blob)
      iex> Mojoler.Own.blob_close(blob)
      :ok
      iex> bin
      <<1, 2, 3>>

  """
  @spec blob_close(blob()) :: :ok
  # coveralls-ignore-next-line
  def blob_close(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the integer token assigned when the blob was opened.

  The token is not a pointer. Pokes do not change it.

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3, 4>>)
      iex> :persistent_term.put(:mojoler_doc_blob_token, blob)
      iex> {:ok, token} = Mojoler.Own.blob_token(blob)
      iex> Mojoler.Own.blob_poke(blob, 1, 9)
      :ok
      iex> Mojoler.Own.blob_token(blob)
      {:ok, token}

  """
  @spec blob_token(blob()) :: {:ok, integer()}
  # coveralls-ignore-next-line
  def blob_token(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Writes `byte` at `index` in the blob.

  `index` is a zero-based integer. `byte` is an integer in `0..255`.
  The write is refused when the blob is borrowed, frozen, or closed.

  ## Returns

    * `:ok`
    * `{:error, :not_mutable}`
    * `{:error, :bounds}` when `index` is outside the blob

  ## Raises

    * `ArgumentError` when `blob` is not a blob, `index` is not an integer,
      or `byte` is not an integer in `0..255`

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1, 2, 3, 4>>)
      iex> :persistent_term.put(:mojoler_doc_blob_poke, blob)
      iex> Mojoler.Own.blob_poke(blob, 1, 8)
      :ok
      iex> Mojoler.Own.blob_poke(blob, 9, 1)
      {:error, :bounds}
      iex> Mojoler.Own.blob_poke(blob, 0, 300)
      ** (ArgumentError) argument error

  """
  @spec blob_poke(blob(), integer(), 0..255) :: :ok | {:error, :not_mutable | :bounds}
  # coveralls-ignore-next-line
  def blob_poke(_blob, _index, _byte), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns a pin that keeps `blob` alive.

  The pin is a separate reference. Collecting it releases the keep.
  Collecting both the pin and the blob runs the blob destructor.

  ## Raises

    * `ArgumentError` when `blob` is not a blob from this module

  ## Examples

      iex> blob = Mojoler.Own.open_blob(<<1>>)
      iex> :persistent_term.put(:mojoler_doc_blob_pin_blob, blob)
      iex> pin = Mojoler.Own.blob_pin(blob)
      iex> :persistent_term.put(:mojoler_doc_blob_pin, pin)
      iex> is_reference(pin)
      true

  """
  @spec blob_pin(blob()) :: pin()
  # coveralls-ignore-next-line
  def blob_pin(_blob), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns how many blob destructors have run in this VM.

  The count starts at 0 and increases by one each time a blob resource is
  collected. It is process-wide, not per blob.

  ## Examples

      iex> is_integer(Mojoler.Own.blob_dtors())
      true

  """
  @spec blob_dtors() :: non_neg_integer()
  # coveralls-ignore-next-line
  def blob_dtors, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Copies `term` into a private environment and returns a handle.

  `term` may be any Elixir term. The copy does not keep the caller's
  process alive.

  ## Examples

      iex> handle = Mojoler.Own.retain_binary(<<9, 8, 7>>)
      iex> :persistent_term.put(:mojoler_doc_retained, handle)
      iex> Mojoler.Own.read_retained(handle)
      <<9, 8, 7>>

  """
  @spec retain_binary(term()) :: retained()
  # coveralls-ignore-next-line
  def retain_binary(_term), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the term stored by `retain_binary/1`.

  ## Raises

    * `ArgumentError` when `handle` is not a retained term from this module

  ## Examples

      iex> handle = Mojoler.Own.retain_binary(<<9, 8, 7>>)
      iex> :persistent_term.put(:mojoler_doc_read_retained, handle)
      iex> Mojoler.Own.read_retained(handle)
      <<9, 8, 7>>

  """
  @spec read_retained(retained()) :: term()
  # coveralls-ignore-next-line
  def read_retained(_handle), do: :erlang.nif_error(:nif_not_loaded)
end
