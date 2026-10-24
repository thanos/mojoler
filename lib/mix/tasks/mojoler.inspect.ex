defmodule Mix.Tasks.Mojoler.Inspect do
  @shortdoc "Show nif_init, undefined symbols, and dynamic dependencies"
  @moduledoc """
  Prints `nif_init`, undefined symbols, and dynamic dependencies for one library.

  `run/1` is the `c:Mix.Task.run/1` callback behind `mix mojoler.inspect`.
  """

  use Mix.Task

  @doc """
  Inspects one shared library.

  `args` is the task argv. The first element is an optional path to a `.so`
  file. When `args` is empty, the path is `priv/native/libpoc.so`.

  ## Returns

  `nil` when the script exits 0.

  ## Raises

    * `Mix.Error` when the script exits non-zero

  ## Examples

      iex> Mix.Tasks.Mojoler.Inspect.run([])
      nil

  """
  @impl Mix.Task
  @spec run([Path.t()]) :: nil
  def run(args) do
    root = Mojoler.Build.root()
    so = List.first(args) || Path.join(root, "priv/native/libpoc.so")

    {out, status} =
      System.cmd("bash", ["scripts/inspect-abi.sh", so], cd: root, stderr_to_stdout: true)

    Mojoler.Shell.conclude(out, status, "inspect")
  end
end
