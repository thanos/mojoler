defmodule Mix.Tasks.Mojoler.Inspect do
  @shortdoc "Show nif_init, undefined symbols, and dynamic dependencies"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    root = Mojoler.Build.root()
    so = List.first(args) || Path.join(root, "priv/native/libpoc.so")

    {out, status} =
      System.cmd("bash", ["scripts/inspect-abi.sh", so], cd: root, stderr_to_stdout: true)

    IO.write(out)

    if status != 0 do
      Mix.raise("inspect failed with status #{status}")
    end
  end
end
