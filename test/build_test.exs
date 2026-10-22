defmodule Mojoler.BuildTest do
  use ExUnit.Case, async: false

  test "a matching fingerprint is a no-op even if the library is loaded" do
    assert Mojoler.Build.decide(true, true, true) == :noop
    assert Mojoler.Build.decide(false, true, true) == :loaded
    assert Mojoler.Build.decide(false, false, false) == :build
    assert {:noop, []} = Mix.Tasks.Compile.Mojoler.run([])
  end
end
