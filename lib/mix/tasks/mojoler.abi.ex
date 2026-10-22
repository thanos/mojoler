defmodule Mix.Tasks.Mojoler.Abi do
  @shortdoc "Regenerate the OTP ABI into a temp directory and diff it"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    root = Mojoler.Build.root()
    {out, status} = System.cmd("bash", ["scripts/check-abi.sh"], cd: root, stderr_to_stdout: true)
    IO.write(out)

    if status != 0 do
      Mix.raise("abi check failed with status #{status}")
    end
  end
end
