defmodule Mojoler.Build do
  @moduledoc """
  Decides whether a native build is required and publishes `.so` files by
  rename. The rename is the publication step. A failed `mojo build` never
  reaches it, so the previous library stays in place.
  """

  def decide(fingerprint_match?, loaded?, outputs_exist?) do
    cond do
      fingerprint_match? and outputs_exist? -> :noop
      loaded? -> :loaded
      true -> :build
    end
  end

  def root do
    Mix.Project.project_file()
    |> Path.dirname()
  end

  def fingerprint(root) do
    {out, 0} = System.cmd("bash", ["scripts/fingerprint.sh"], cd: root, stderr_to_stdout: true)
    String.trim(out)
  end

  def outputs_present?(dir) do
    ~w(libpoc.so libtwice.so libterm.so libown.so libsched.so libdsl_arith.so libdsl_bytes.so libdsl_box.so)
    |> Enum.all?(fn name -> File.regular?(Path.join(dir, name)) end)
  end

  def any_loaded?(names) do
    Enum.any?(names, &Mojoler.Nif.loaded?/1)
  end

  def publish!(staging, dest) do
    File.mkdir_p!(dest)
    names = staging |> Path.join("lib*.so") |> Path.wildcard() |> Enum.map(&Path.basename/1)

    if any_loaded?(names) do
      {:error, "a Mojoler library is already loaded in this VM; restart it before rebuilding"}
    else
      Enum.each(names, fn name ->
        File.rename!(Path.join(staging, name), Path.join(dest, name))
      end)

      inputs = Path.join(staging, "link-inputs.txt")

      if File.regular?(inputs) do
        File.cp!(inputs, Path.join(dest, "link-inputs.txt"))
      end

      :ok
    end
  end
end
