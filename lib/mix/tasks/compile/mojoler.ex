defmodule Mix.Tasks.Compile.Mojoler do
  @moduledoc """
  Builds the Mojo NIFs into `priv/native`. A second run with the same sources,
  headers, and compiler is a no-op.
  """

  use Mix.Task.Compiler

  @recursive true

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
        {:error,
         [
           %Mix.Task.Compiler.Diagnostic{
             file: "priv/native",
             severity: :error,
             message: "native library is already loaded in this VM; restart before a rebuild",
             position: 0,
             compiler_name: "mojoler"
           }
         ]}

      :build ->
        staging = Path.join(dest, "staging")
        File.rm_rf!(staging)
        File.mkdir_p!(staging)

        env = [{"MOJOLER_OUT", staging}]

        case System.cmd("bash", ["scripts/build-native.sh"],
               cd: root,
               env: env,
               stderr_to_stdout: true
             ) do
          {_out, 0} ->
            case Mojoler.Build.publish!(staging, dest) do
              :ok ->
                File.write!(stamp, current <> "\n")
                File.rm_rf!(staging)
                {:ok, []}

              {:error, message} ->
                {:error,
                 [
                   %Mix.Task.Compiler.Diagnostic{
                     file: "priv/native",
                     severity: :error,
                     message: message,
                     position: 0,
                     compiler_name: "mojoler"
                   }
                 ]}
            end

          {out, status} ->
            File.rm_rf!(staging)

            {:error,
             [
               %Mix.Task.Compiler.Diagnostic{
                 file: "scripts/build-native.sh",
                 severity: :error,
                 message: "native build failed (#{status})\n" <> out,
                 position: 0,
                 compiler_name: "mojoler"
               }
             ]}
        end
    end
  end
end
