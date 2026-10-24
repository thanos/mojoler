defmodule ChildTest do
  use ExUnit.Case

  test "an umbrella child loads the same NIF" do
    assert Mojoler.POC.add(20, 22) == 42
    assert Mojoler.Twice.double(21) == 42
  end
end