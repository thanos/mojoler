defmodule Mojoler.SchedTest do
  use ExUnit.Case, async: false

  doctest Mojoler.Sched

  test "hold copies before the dirty loop and returns the same bytes" do
    assert Mojoler.Sched.hold(<<1, 2, 3>>, 20) == <<1, 2, 3>>
    assert Mojoler.Sched.io_ping() == :ok
  end

  test "an Elixir yield timeout does not cancel the burn" do
    task = Task.async(fn -> Mojoler.Sched.burn(200) end)
    assert Task.yield(task, 30) == nil
    assert Task.await(task, 2_000) == :ok
  end

  test "one scheduler still receives heartbeats during a dirty burn" do
    root = Path.expand("..", __DIR__)

    {out, status} =
      System.cmd("bash", ["scripts/measure-heartbeat.sh"],
        cd: root,
        env: [{"MOJOLER_SKIP_BUILD", "1"}],
        stderr_to_stdout: true
      )

    assert status == 0, out
    assert out =~ "heartbeat ok"
  end
end
