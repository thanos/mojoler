defmodule ConsumerTest do
  use ExUnit.Case

  doctest Consumer

  test "the dependency's NIF adds" do
    assert Consumer.add(20, 22) == 42
  end
end