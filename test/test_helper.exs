# Rebuild the Mojo library on every test run so a stale .so cannot pass.
{output, status} =
  System.cmd("bash", ["scripts/build-native.sh"],
    cd: Path.expand("..", __DIR__),
    stderr_to_stdout: true
  )

if status != 0 do
  IO.puts(output)
  raise "native build failed with status #{status}"
end

ExUnit.start()
