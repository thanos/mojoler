defmodule Mojoler.DslTest do
  use ExUnit.Case, async: false

  test "checked add matches the Stage 0 contract" do
    assert Mojoler.Dsl.Arith.add(20, 22) == {:ok, 42}
    assert Mojoler.Dsl.Arith.add(9_223_372_036_854_775_807, 1) == {:error, :overflow}
  end

  test "copy shift reports the payload size and borrow refuses a non-binary" do
    assert Mojoler.Dsl.Bytes.shift(<<1, 2, 255>>) == {:ok, <<2, 3, 0>>, 3}
    assert Mojoler.Dsl.Bytes.shift(<<>>) == {:ok, <<>>, 0}
    assert Mojoler.Dsl.Bytes.borrow_len(<<1, 2, 3, 4>>) == {:ok, 4}
    assert Mojoler.Dsl.Bytes.borrow_len([1, 2]) == {:error, :not_binary}
    assert Mojoler.Dsl.Bytes.borrow_len(<<1::7>>) == {:error, :not_binary}
  end

  test "a generated resource uses the author step" do
    box = Mojoler.Dsl.Box.open()
    assert Mojoler.Dsl.Box.bump(box, 20) == 20
    assert Mojoler.Dsl.Box.bump(box, 22) == 42
  end

  test "arith and bytes load in one VM" do
    assert Mojoler.Dsl.Arith.add(1, 1) == {:ok, 2}
    assert Mojoler.Dsl.Bytes.borrow_len(<<0>>) == {:ok, 1}
  end

  test "invalid declarations fail at generation" do
    root = Path.expand("..", __DIR__)

    for decl <- ["tools/dsl/bad_schedule.json", "tools/dsl/bad_borrow.json"] do
      {out, status} =
        System.cmd("python3", ["tools/dsl/generate.py", "--decls", decl],
          cd: root,
          stderr_to_stdout: true
        )

      assert status == 1
      assert out =~ "dsl:"
    end
  end

  test "regenerating the committed wrappers is a no-op" do
    root = Path.expand("..", __DIR__)

    {out, 0} =
      System.cmd("python3", ["tools/dsl/generate.py", "--check"],
        cd: root,
        stderr_to_stdout: true
      )

    assert out =~ "dsl mojo: matches"
  end
end
