defmodule Mojoler.TermTest do
  use ExUnit.Case

  doctest Mojoler.Term

  @max 9_223_372_036_854_775_807
  @min -9_223_372_036_854_775_808

  test "signed and unsigned integers round-trip at the edges" do
    assert Mojoler.Term.echo_i64(@max) == @max
    assert Mojoler.Term.echo_i64(@min) == @min
    assert Mojoler.Term.echo_i64(0) == 0
    assert Mojoler.Term.echo_u64(0) == 0
    assert Mojoler.Term.echo_u64(18_446_744_073_709_551_615) == 18_446_744_073_709_551_615
    assert Mojoler.Term.echo_i32(2_147_483_647) == 2_147_483_647
    assert Mojoler.Term.echo_i32(-2_147_483_648) == -2_147_483_648
    assert Mojoler.Term.echo_u32(4_294_967_295) == 4_294_967_295
  end

  test "integers outside the declared width are badarg" do
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_i64(@max + 1) end
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_i64(@min - 1) end
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_u64(-1) end
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_i32(2_147_483_648) end
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_u32(-1) end
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_i64(:nope) end
  end

  test "checked add matches Elixir or returns overflow" do
    assert Mojoler.Term.add_i64(20, 22) == {:ok, 42}
    assert Mojoler.Term.add_i64(@max, 1) == {:error, :overflow}
    assert_raise ArgumentError, fn -> Mojoler.Term.add_i64(@max + 1, 0) end
  end

  test "floats round-trip and integers are not coerced" do
    assert Mojoler.Term.echo_f64(1.5) == 1.5
    assert Mojoler.Term.echo_f64(0.0) == 0.0
    assert_raise ArgumentError, fn -> Mojoler.Term.echo_f64(1) end
  end

  test "only the fixed atom vocabulary is accepted" do
    for atom <- [:ok, :error, nil, true, false] do
      assert Mojoler.Term.echo_atom(atom) == atom
    end

    assert Mojoler.Term.echo_atom(:other) == {:error, :unknown_atom}
  end

  test "copied binaries match Elixir, including empty, NUL, and sub-binaries" do
    for bin <- [
          <<>>,
          <<0, 1, 0>>,
          "héllo",
          binary_part(<<0::size(100)-unit(8), 9, 8, 7>>, 100, 3)
        ] do
      assert {:ok, ^bin, n} = Mojoler.Term.copy_binary(bin)
      assert n == byte_size(bin)
    end

    assert Mojoler.Term.copy_binary(<<1::7>>) == {:error, :not_binary}
  end

  test "a borrowed binary keeps one data pointer and a direct output is filled in place" do
    bin = :binary.copy(<<1>>, 1000)
    assert {:ok, 1000, 1} = Mojoler.Term.borrow_stable(bin)
    assert {:ok, out} = Mojoler.Term.fill_output(4)
    assert out == <<7, 7, 7, 7>>
    assert {:ok, <<>>} = Mojoler.Term.fill_output(0)
  end

  test "text length rejects invalid UTF-8 and does not normalize" do
    assert Mojoler.Term.text_len("héllo") == {:ok, byte_size("héllo")}
    assert Mojoler.Term.text_len(<<0xFF>>) == {:error, :invalid_utf8}
    assert Mojoler.Term.text_len(<<>>) == {:ok, 0}
  end

  test "tuples, lists, and maps match an Elixir reference or a tagged error" do
    assert Mojoler.Term.tuple_sum({20, 22}) == {:ok, 42}
    assert Mojoler.Term.tuple_sum({1}) == {:error, :bad_arity}
    assert Mojoler.Term.tuple_sum({1, :a}) == {:error, :bad_element}
    assert Mojoler.Term.list_sum([1, 2, 3]) == {:ok, 6}
    assert Mojoler.Term.list_sum([1 | 2]) == {:error, :improper_list}
    assert Mojoler.Term.list_sum(Enum.to_list(1..65)) == {:error, :too_long}
    assert Mojoler.Term.map_n(%{n: 7}) == {:ok, %{n: 7}}
    assert Mojoler.Term.map_n(%{}) == {:error, :missing}
    assert Mojoler.Term.map_n(%{n: :a}) == {:error, :bad_element}
    assert Mojoler.Term.map_n(%{n: 7, extra: 1}) == {:ok, %{n: 7}}
    assert Mojoler.Term.list_sum([[1]]) == {:error, :bad_element}
  end

  test "random signed adds match Elixir until overflow" do
    for a <- [-3, -1, 0, 1, 20], b <- [-22, 0, 22] do
      assert Mojoler.Term.add_i64(a, b) == {:ok, a + b}
    end
  end

  test "this OTP refuses to construct a non-finite float" do
    assert_raise ArithmeticError, fn -> 0.0 / 0.0 end
    assert Mojoler.Term.echo_f64(1.5) == 1.5
  end
end
