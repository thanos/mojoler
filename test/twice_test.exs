defmodule Mojoler.TwiceTest do
  use ExUnit.Case

  doctest Mojoler.Twice

  test "double(21) == 42" do
    assert Mojoler.Twice.double(21) == 42
  end

  test "double rejects overflow and non-integers" do
    assert_raise ArgumentError, fn -> Mojoler.Twice.double(9_223_372_036_854_775_807) end
    assert_raise ArgumentError, fn -> Mojoler.Twice.double(:nope) end
  end

  test "the twice library does not define the ABI structs itself" do
    source = File.read!("native/twice.mojo")
    refute source =~ "struct ErlNifFunc"
    refute source =~ "struct ErlNifEntry"
    assert source =~ "from mojoler.abi.otp_nif import"
  end
end
