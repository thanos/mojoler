# Quickstart

You need [Mojo 1.1.0](https://mojolang.org/install/), Elixir `~> 1.20`, and OTP 28.3.1. `mojo` can be on `PATH` or in a `.venv` at the project root.

```sh
uv venv && uv pip install -r requirements.txt
mix deps.get
mix test
```

`mix test` compiles the NIFs, then runs ExUnit. A second run with the same sources skips `mojo build`.

In IEx:

```elixir
iex> Mojoler.POC.add(20, 22)
42

iex> Mojoler.Term.list_sum([20, 22, 19, 25])
{:ok, 86}

iex> Mojoler.Term.echo_f64(22.3)
22.3

iex> Mojoler.Term.copy_binary(<<1, 2, 3>>)
{:ok, <<1, 2, 3>>, 3}
```

`list_sum/1` is the integer form of the total in the [Mojo quickstart](https://mojolang.org/docs/manual/quickstart/). Floats go through `echo_f64/1`. How those values are owned, copied, and destroyed is [Value ownership and value lifecycles](ownership.md).

The Mojo language tours those calls come from:

- [Mojo quickstart](https://mojolang.org/docs/manual/quickstart/) — lists, functions, `raises`, and `try` / `except`.
- [Get started](https://mojolang.org/docs/manual/get-started/) — Conway’s Game of Life, structs, and the `^` transfer.
- [Jupyter notebooks](https://mojolang.org/docs/tools/notebooks/) — `%%mojo` cells. GPU cells need MAX.

Another application that depends on this package:

```sh
cd examples/consumer
mix test
```

The function list is [API.md](API.md). GPU batch, when MAX is installed: `scripts/gpu-batch.sh`.
