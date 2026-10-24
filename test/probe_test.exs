defmodule Mojoler.ProbeTest do
  use ExUnit.Case, async: false

  test "an aborting NIF dies in a child BEAM" do
    root = Path.expand("..", __DIR__)

    {out, status} =
      System.cmd("bash", ["scripts/probe-abort.sh"], cd: root, stderr_to_stdout: true)

    assert status == 0, out
    assert out =~ "probe ok"
    refute out =~ "probe_exit 0\n"
  end
end
