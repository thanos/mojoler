defmodule Mojoler.Shell do
  @moduledoc """
  Exit check for Mix tasks that run a shell script.

  The task prints the script output. A non-zero status becomes `Mix.Error`.
  """

  @doc """
  Writes `output` and returns `nil` when `status` is 0.

  `label` is the script name used in the error. There are no optional arguments.

  ## Raises

    * `Mix.Error` when `status` is not 0

  ## Examples

      iex> Mojoler.Shell.conclude("ready\\n", 0, "doctor")
      nil

      iex> Mojoler.Shell.conclude("nope\\n", 7, "doctor")
      ** (Mix.Error) doctor failed with status 7

  """
  @spec conclude(String.t(), integer(), String.t()) :: nil
  def conclude(output, status, label)
      when is_binary(output) and is_integer(status) and is_binary(label) do
    IO.write(output)

    if status != 0 do
      Mix.raise("#{label} failed with status #{status}")
    end
  end
end
