defmodule Mix.Tasks.Mojoler.Doctor do
  @shortdoc "Print the toolchain pin and whether this machine can build"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    root = Mojoler.Build.root()
    {out, status} = System.cmd("bash", ["scripts/doctor.sh"], cd: root, stderr_to_stdout: true)
    IO.write(out)

    if status != 0 do
      Mix.raise("doctor failed with status #{status}")
    end
  end
end
