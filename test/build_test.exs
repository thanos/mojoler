defmodule Mojoler.BuildTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Compile.Mojoler, as: Compile

  doctest Mojoler.Nif
  doctest Mojoler.Build
  doctest Mojoler.Shell
  doctest Compile
  doctest Mix.Tasks.Mojoler.Doctor
  doctest Mix.Tasks.Mojoler.Abi
  doctest Mix.Tasks.Mojoler.Inspect

  test "a matching fingerprint is a no-op even if the library is loaded" do
    assert Mojoler.Build.decide(true, true, true) == :noop
    assert Mojoler.Build.decide(false, true, true) == :loaded
    assert Mojoler.Build.decide(false, false, false) == :build
    assert {:noop, []} = Compile.run([])
  end

  test "a stale fingerprint is refused while a library is loaded" do
    dest = Path.join(Mojoler.Build.root(), "priv/native")
    stamp = Path.join(dest, "FINGERPRINT")
    original = File.read!(stamp)
    on_exit(fn -> File.write!(stamp, original) end)

    File.write!(stamp, "stale\n")

    assert {:error, [diagnostic]} = Compile.run([])
    assert diagnostic.file == "priv/native"
    assert diagnostic.severity == :error
    assert diagnostic.compiler_name == "mojoler"
    assert diagnostic.message =~ "already loaded"
  end

  test "publish leaves a loaded library in place" do
    parent = Path.join(System.tmp_dir!(), "mojoler-loaded-#{System.unique_integer([:positive])}")
    staging = Path.join(parent, "staging")
    dest = Path.join(parent, "out")
    File.mkdir_p!(staging)
    File.write!(Path.join(staging, "libpoc.so"), "not a library")
    on_exit(fn -> File.rm_rf!(parent) end)

    assert {:error, message} = Mojoler.Build.publish!(staging, dest)
    assert message =~ "already loaded"
    refute File.regular?(Path.join(dest, "libpoc.so"))
  end

  test "publish moves an unloaded library and the link inputs" do
    parent = Path.join(System.tmp_dir!(), "mojoler-publish-#{System.unique_integer([:positive])}")
    staging = Path.join(parent, "staging")
    dest = Path.join(parent, "out")
    File.mkdir_p!(staging)
    File.write!(Path.join(staging, "libdoctest.so"), "x")
    File.write!(Path.join(staging, "link-inputs.txt"), "native/poc.mojo\n")
    on_exit(fn -> File.rm_rf!(parent) end)

    assert :ok = Mojoler.Build.publish!(staging, dest)
    assert File.read!(Path.join(dest, "libdoctest.so")) == "x"
    assert File.read!(Path.join(dest, "link-inputs.txt")) == "native/poc.mojo\n"
  end
end
