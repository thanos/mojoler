defmodule Mojoler.Build do
  @moduledoc """
  Decides whether a native build is required and publishes `.so` files by rename.

  The rename is the publication step. A failed `mojo build` never reaches it,
  so the previous libraries stay in place.
  """

  @typedoc """
  What the compiler should do with the current fingerprint and load state.

    * `:noop` — the fingerprint matches and every library file is present
    * `:loaded` — a rebuild is required, but this VM has already mapped a library
    * `:build` — compile into a staging directory, then publish

  ## Examples

      iex> Mojoler.Build.decide(true, true, true)
      :noop

  """
  @type decision :: :noop | :loaded | :build

  @doc """
  Chooses the next compile step.

  `fingerprint_match?` is true when `priv/native/FINGERPRINT` equals the
  current fingerprint. `loaded?` is true when this VM has marked any product
  library. `outputs_exist?` is true when every expected `.so` is a regular file.
  None of the arguments is optional.

  ## Examples

      iex> Mojoler.Build.decide(true, true, true)
      :noop

      iex> Mojoler.Build.decide(false, true, true)
      :loaded

      iex> Mojoler.Build.decide(false, false, false)
      :build

      iex> Mojoler.Build.decide(true, false, false)
      :build

  """
  @spec decide(boolean(), boolean(), boolean()) :: decision()
  def decide(fingerprint_match?, loaded?, outputs_exist?) do
    cond do
      fingerprint_match? and outputs_exist? -> :noop
      loaded? -> :loaded
      true -> :build
    end
  end

  @doc """
  Returns the directory that contains this project's `mix.exs`.

  ## Examples

      iex> File.regular?(Path.join(Mojoler.Build.root(), "mix.exs"))
      true

  """
  @spec root() :: Path.t()
  def root do
    Mix.Project.project_file()
    |> Path.dirname()
  end

  @doc """
  Returns the sha256 fingerprint of the native inputs.

  `root` is the project directory. The script hashes Mojo sources, the ABI
  tools, the build scripts, `erl_nif.h`, the Mojo version, the compiler
  triple, and the link flags. There is no optional argument.

  ## Returns

  A 64-character hex string.

  ## Examples

      iex> fp = Mojoler.Build.fingerprint(Mojoler.Build.root())
      iex> byte_size(fp) == 64
      true

  """
  @spec fingerprint(Path.t()) :: String.t()
  def fingerprint(root) do
    {out, 0} = System.cmd("bash", ["scripts/fingerprint.sh"], cd: root, stderr_to_stdout: true)
    String.trim(out)
  end

  @doc """
  Returns whether `dir` contains every product library.

  The expected names are `libpoc.so`, `libtwice.so`, `libterm.so`,
  `libown.so`, `libsched.so`, `libdsl_arith.so`, `libdsl_bytes.so`,
  and `libdsl_box.so`.

  ## Examples

      iex> Mojoler.Build.outputs_present?(Path.join(Mojoler.Build.root(), "priv/native"))
      true

  """
  @spec outputs_present?(Path.t()) :: boolean()
  def outputs_present?(dir) do
    ~w(libpoc.so libtwice.so libterm.so libown.so libsched.so libdsl_arith.so libdsl_bytes.so libdsl_box.so)
    |> Enum.all?(fn name -> File.regular?(Path.join(dir, name)) end)
  end

  @doc """
  Returns whether any name in `names` was marked loaded.

  `names` are basenames such as `"libpoc.so"`. An empty list is `false`.

  ## Examples

      iex> Mojoler.Build.any_loaded?([])
      false
      iex> Mojoler.Nif.mark!("doctest-any-loaded")
      :ok
      iex> Mojoler.Build.any_loaded?(["doctest-any-loaded.so"])
      true

  """
  @spec any_loaded?([Mojoler.Nif.library()]) :: boolean()
  def any_loaded?(names) do
    Enum.any?(names, &Mojoler.Nif.loaded?/1)
  end

  @doc """
  Moves `lib*.so` from `staging` to `dest`.

  `staging` and `dest` are directories. When this VM has already loaded one
  of those libraries, nothing is renamed.

  Also copies `link-inputs.txt` when that file is present in `staging`.

  ## Returns

    * `:ok` after the renames
    * `{:error, message}` when a listed library is already loaded

  `File.rename!/2` raises `File.Error` when the rename itself fails.

  ## Examples

      iex> parent = Path.join(System.tmp_dir!(), "mojoler-doctest-#{System.unique_integer([:positive])}")
      iex> staging = Path.join(parent, "staging")
      iex> dest = Path.join(parent, "dest")
      iex> File.mkdir_p!(staging)
      :ok
      iex> Mojoler.Build.publish!(staging, dest)
      :ok
      iex> is_list(File.rm_rf!(parent))
      true

  """
  @spec publish!(Path.t(), Path.t()) :: :ok | {:error, String.t()}
  def publish!(staging, dest) do
    File.mkdir_p!(dest)
    names = staging |> Path.join("lib*.so") |> Path.wildcard() |> Enum.map(&Path.basename/1)

    if any_loaded?(names) do
      {:error, "a Mojoler library is already loaded in this VM; restart it before rebuilding"}
    else
      Enum.each(names, fn name ->
        File.rename!(Path.join(staging, name), Path.join(dest, name))
      end)

      inputs = Path.join(staging, "link-inputs.txt")

      if File.regular?(inputs) do
        File.cp!(inputs, Path.join(dest, "link-inputs.txt"))
      end

      :ok
    end
  end
end
