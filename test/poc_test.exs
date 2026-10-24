defmodule Mojoler.POCTest do
  use ExUnit.Case

  doctest Mojoler.POC

  @max 9_223_372_036_854_775_807
  @min -9_223_372_036_854_775_808

  test "add(20, 22) == 42" do
    assert Mojoler.POC.add(20, 22) == 42
  end

  test "negatives and zeros" do
    assert Mojoler.POC.add(-5, -7) == -12
    assert Mojoler.POC.add(-1, -1) == -2
    assert Mojoler.POC.add(1, -1) == 0
    assert Mojoler.POC.add(0, 0) == 0
    assert Mojoler.POC.add(@min, 0) == @min
    assert Mojoler.POC.add(@max, 0) == @max
    assert Mojoler.POC.add(@min, @max) == -1
    assert Mojoler.POC.add(@max, @min) == -1
    assert Mojoler.POC.add(@min, 1) == @min + 1
    assert Mojoler.POC.add(@max, -1) == @max - 1
  end

  test "overflow and values outside int64 are badarg" do
    assert_raise ArgumentError, fn -> Mojoler.POC.add(@max, 1) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(1, @max) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(@min, -1) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(-1, @min) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(@max + 1, 0) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(@min - 1, 0) end
  end

  test "non-integers are badarg" do
    assert_raise ArgumentError, fn -> Mojoler.POC.add(1, :nope) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add(1.5, 2) end
    assert_raise ArgumentError, fn -> Mojoler.POC.add("1", 2) end
  end

  test "wrong arity is rejected before the native callback" do
    assert_raise UndefinedFunctionError, fn ->
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Mojoler.POC, :add, [1])
    end
  end

  test "repeated calls" do
    assert Enum.map(1..200, &Mojoler.POC.add(&1, 1)) == Enum.map(1..200, &(&1 + 1))
  end

  test "concurrent calls" do
    results =
      1..40
      |> Task.async_stream(fn i -> Mojoler.POC.add(i, i) end, max_concurrency: 8)
      |> Enum.map(fn {:ok, value} -> value end)

    assert results == Enum.map(1..40, &(&1 * 2))
  end

  test "nif version reported by this OTP" do
    assert :erlang.system_info(:nif_version) == ~c"2.17"
  end

  test "a second load_nif in this VM is rejected" do
    assert {:error, {:reload, ~c"NIF library already loaded (reload disallowed since OTP 20)."}} =
             Mojoler.POC.reload()
  end

  test "fresh OS process loads the NIF, computes 42, and exits" do
    code = """
    path = #{inspect(String.to_charlist(Application.app_dir(:mojoler, "priv/native/libpoc")))}
    defmodule Mojoler.POC do
      @on_load :load_nif
      @path path
      def load_nif, do: :erlang.load_nif(@path, 0)
      def add(_, _), do: :erlang.nif_error(:nif_not_loaded)
    end
    if Mojoler.POC.add(20, 22) != 42, do: raise "bad"
    """

    assert {_, 0} = System.cmd("elixir", ["-e", code], stderr_to_stdout: true)
  end

  test "the shared library exports nif_init and imports enif_get_long" do
    so = Application.app_dir(:mojoler, "priv/native/libpoc.so")
    {defined, 0} = nm_defined(so)
    {undefined, 0} = System.cmd("nm", ["-u", so])
    {deps, 0} = shared_deps(so)

    # Mach-O prints a leading underscore. ELF does not. Either form matches.
    assert defined =~ "nif_init"
    assert undefined =~ "enif_get_long"
    assert undefined =~ "enif_make_long"
    assert undefined =~ "enif_make_badarg"
    refute undefined =~ "enif_get_int64"

    if match?({:unix, :darwin}, :os.type()) do
      assert deps =~ "libKGENCompilerRTShared"
      assert deps =~ "libSystem.B.dylib"
    else
      # Linux ldd lists libc and the dynamic linker. libKGENCompilerRTShared
      # is not a DT_NEEDED entry, and load_nif still succeeds.
      assert deps =~ "libc.so"
      refute deps =~ "libKGENCompilerRTShared"
    end
  end

  defp nm_defined(so) do
    args =
      case :os.type() do
        {:unix, :darwin} -> ["-gU", so]
        _ -> ["-g", "--defined-only", so]
      end

    System.cmd("nm", args)
  end

  defp shared_deps(so) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("otool", ["-L", so])
      _ -> System.cmd("ldd", [so])
    end
  end
end
