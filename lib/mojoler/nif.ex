defmodule Mojoler.Nif do
  @moduledoc """
  Shared path and load bookkeeping.

  `:erlang.load_nif/2` must run inside the module named by the NIF entry.
  This module builds that path and records a successful load. It does not
  call `:erlang.load_nif/2`.
  """

  @typedoc """
  File name of a built library, including the `.so` suffix OTP appends.

  ## Examples

      "libpoc.so"

  """
  @type library :: String.t()

  @doc """
  Returns the load path for `priv/native/<stem>`.

  `stem` is the file name without `.so`. OTP appends `.so` on Darwin and Linux.
  There is no optional argument.

  ## Returns

  A charlist. `:erlang.load_nif/2` accepts that form.

  ## Examples

      iex> path = Mojoler.Nif.path("libpoc")
      iex> List.ends_with?(path, ~c"libpoc")
      true

  """
  @spec path(String.t()) :: charlist()
  def path(stem) when is_binary(stem) do
    :mojoler
    |> Application.app_dir("priv/native/" <> stem)
    |> String.to_charlist()
  end

  @doc """
  Records that `stem <> ".so"` has been loaded in this VM.

  `stem` is the file name without `.so`. The compiler reads this mark and
  will not replace a library this VM has already mapped.

  ## Returns

  `:ok`.

  ## Examples

      iex> Mojoler.Nif.mark!("doctest-mark")
      :ok
      iex> Mojoler.Nif.loaded?("doctest-mark.so")
      true

  """
  @spec mark!(String.t()) :: :ok
  def mark!(stem) when is_binary(stem) do
    :persistent_term.put({:mojoler_loaded, stem <> ".so"}, true)
    :ok
  end

  @doc """
  Returns whether `basename` was marked loaded in this VM.

  `basename` includes the `.so` suffix. An unknown name is `false`.
  There is no optional argument.

  ## Examples

      iex> Mojoler.Nif.loaded?("not-a-library.so")
      false

  """
  @spec loaded?(library()) :: boolean()
  def loaded?(basename) when is_binary(basename) do
    :persistent_term.get({:mojoler_loaded, basename}, false)
  end
end
