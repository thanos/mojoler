defmodule Mix.Tasks.Compile.Mojoler do
  @moduledoc """
  Builds the Mojo NIFs into `priv/native`.

  This is the `Mix.Task.Compiler` callback `c:Mix.Task.Compiler.run/1`.
  Mix calls it because `mix.exs` appends `:mojoler` to the compiler list.
  A second run with the same sources, headers, and compiler returns `{:noop, []}`.

  The callback receives the compiler argv and ignores it. It returns one of:

    * `{:ok, []}` after a build
    * `{:noop, []}` when the fingerprint and the libraries are unchanged
    * `{:error, [diagnostic]}` when the VM has already loaded a library that
      would be replaced, or when `mojo build` fails

  `diagnostic` is a `Mix.Task.Compiler.Diagnostic`. The fields this task sets
  are:

    * `:file` — `priv/native` or `scripts/build-native.sh`
    * `:severity` — `:error`
    * `:message` — the build or load failure
    * `:position` — `0`
    * `:compiler_name` — `"mojoler"`

  ## Examples

      iex> Mix.Tasks.Compile.Mojoler.run([])
      {:noop, []}

  """

  use Mix.Task.Compiler

  @recursive true

  @doc """
  Runs the native build.

  `args` is the compiler argv. It is ignored. There is no optional argument
  beyond that ignored list.

  See the module docs for the return values and the diagnostic fields.

  ## Examples

      iex> Mix.Tasks.Compile.Mojoler.run(["--force"])
      {:noop, []}

  """
  @impl Mix.Task.Compiler
  @spec run([String.t()]) ::
          {:ok, []}
          | {:noop, []}
          | {:error, [Mix.Task.Compiler.Diagnostic.t()]}
  def run(_args) do
    root = Mojoler.Build.root()
    dest = Path.join(root, "priv/native")
    stamp = Path.join(dest, "FINGERPRINT")
    current = Mojoler.Build.fingerprint(root)
    previous = if File.regular?(stamp), do: String.trim(File.read!(stamp)), else: ""
    match? = current == previous
    present? = Mojoler.Build.outputs_present?(dest)

    loaded? =
      Mojoler.Build.any_loaded?(
        ~w(libpoc.so libtwice.so libterm.so libown.so libsched.so libdsl_arith.so libdsl_bytes.so libdsl_box.so)
      )

    case Mojoler.Build.decide(match?, loaded?, present?) do
      :noop ->
        {:noop, []}

      :loaded ->
        diagnostic(
          "priv/native",
          "native library is already loaded in this VM; restart before a rebuild"
        )

      :build ->
        build(root, dest, stamp, current)
    end
  end

  defp build(root, dest, stamp, current) do
    staging = Path.join(dest, "staging")
    File.rm_rf!(staging)
    File.mkdir_p!(staging)

    case System.cmd("bash", ["scripts/build-native.sh"],
           cd: root,
           env: [{"MOJOLER_OUT", staging}],
           stderr_to_stdout: true
         ) do
      {_out, 0} ->
        publish(staging, dest, stamp, current)

      {out, status} ->
        File.rm_rf!(staging)
        diagnostic("scripts/build-native.sh", "native build failed (#{status})\n" <> out)
    end
  end

  defp publish(staging, dest, stamp, current) do
    case Mojoler.Build.publish!(staging, dest) do
      :ok ->
        File.write!(stamp, current <> "\n")
        File.rm_rf!(staging)
        {:ok, []}

      {:error, message} ->
        diagnostic("priv/native", message)
    end
  end

  defp diagnostic(file, message) do
    {:error,
     [
       %Mix.Task.Compiler.Diagnostic{
         file: file,
         severity: :error,
         message: message,
         position: 0,
         compiler_name: "mojoler"
       }
     ]}
  end
end
