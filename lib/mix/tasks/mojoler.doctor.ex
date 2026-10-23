defmodule Mix.Tasks.Mojoler.Doctor do
  @shortdoc "Print the toolchain pin and whether this machine can build"
  @moduledoc """
  Prints the toolchain check from `scripts/doctor.sh`.

  This is the `Mix.Task` callback `c:Mix.Task.run/1`. A task module implements
  that callback and Mix invokes it for `mix mojoler.doctor`.

  ## Examples

      defmodule Mix.Tasks.Example.Hello do
        use Mix.Task

        @impl Mix.Task
        def run(_args) do
          Mix.shell().info("hello")
        end
      end

  """

  use Mix.Task

  @doc """
  Runs the doctor script and writes its output.

  `args` is ignored.

  ## Returns

  `nil` when the script exits 0.

  ## Raises

    * `Mix.Error` when the script exits non-zero

  ## Examples

      iex> Mix.Tasks.Mojoler.Doctor.run([])
      nil

  """
  @impl Mix.Task
  @spec run([String.t()]) :: nil
  def run(_args) do
    root = Mojoler.Build.root()
    {out, status} = System.cmd("bash", ["scripts/doctor.sh"], cd: root, stderr_to_stdout: true)
    Mojoler.Shell.conclude(out, status, "doctor")
  end
end
