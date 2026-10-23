defmodule Mix.Tasks.Mojoler.Abi do
  @shortdoc "Regenerate the OTP ABI into a temp directory and diff it"
  @moduledoc """
  Runs `scripts/check-abi.sh`.

  The script regenerates the ABI, diffs it against the committed Mojo file,
  checks struct layout, rejects a misspelled import, and checks the product
  libraries. `run/1` is the `c:Mix.Task.run/1` callback behind `mix mojoler.abi`.
  """

  use Mix.Task

  @doc """
  Runs the ABI check and writes its output.

  `args` is ignored.

  ## Returns

  `nil` when the script exits 0.

  ## Raises

    * `Mix.Error` when the script exits non-zero

  ## Examples

      iex> Mix.Tasks.Mojoler.Abi.run([])
      nil

  """
  @impl Mix.Task
  @spec run([String.t()]) :: nil
  def run(_args) do
    root = Mojoler.Build.root()
    {out, status} = System.cmd("bash", ["scripts/check-abi.sh"], cd: root, stderr_to_stdout: true)
    Mojoler.Shell.conclude(out, status, "abi check")
  end
end
