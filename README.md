# Mojoler

[![Hex.pm](https://img.shields.io/hexpm/v/mojoler.svg)](https://hex.pm/packages/mojoler)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/mojoler)
[![Hex Downloads](https://img.shields.io/hexpm/dt/mojoler.svg)](https://hex.pm/packages/mojoler)
[![License](https://img.shields.io/hexpm/l/mojoler.svg)](https://github.com/thanos/mojoler/blob/v0.1.0/LICENSE)
[![CI](https://github.com/thanos/mojoler/actions/workflows/linux.yml/badge.svg)](https://github.com/thanos/mojoler/actions/workflows/linux.yml)
[![Coverage](https://coveralls.io/repos/github/thanos/mojoler/badge.svg)](https://coveralls.io/github/thanos/mojoler)

Mojoler loads Mojo as an OTP NIF. You call an Elixir function. The body runs in Mojo.

## Installation

### Mojo

Mojoler builds its shared libraries when the project compiles. Install [Mojo 1.1.0](https://mojolang.org/install/) and leave `mojo` on `PATH`. A project virtualenv works too:

```sh
uv venv && uv pip install -r requirements.txt
```

CPU code uses that Mojo package. GPU examples need the separate `max` pin in `requirements-gpu.txt`.

### Elixir

The package is [on Hex](https://hex.pm/packages/mojoler). Add it to `mix.exs`:

```elixir
def deps do
  [
    {:mojoler, "~> 0.1.0"}
  ]
end
```

Requires Elixir `~> 1.20` and OTP 28.3.1. The compatibility table is [docs/compatibility.md](docs/compatibility.md).

## Documentation

[https://hexdocs.pm/mojoler](https://hexdocs.pm/mojoler)

Start with the [quickstart](docs/quickstart.md). Value ownership and lifecycles are [docs/ownership.md](docs/ownership.md). The function list is [docs/API.md](docs/API.md).

## Platforms

- Linux
- macOS

`mix compile` produces `priv/native/*.so`. The Mojo runtime stays in the Mojo install. It is not part of the Hex tarball.

## Mojo NIFs

Mojo owns its values. The BEAM owns Erlang terms. Mojoler copies or borrows across that line on purpose, and the Elixir return value is always a term.

### Checked addition

```elixir
iex> Mojoler.POC.add(20, 22)
42
```

`add/2` is signed 64-bit addition. A value that does not fit, a non-integer, or a sum that overflows raises `ArgumentError`.

The same addition with an explicit ok/error tuple:

```elixir
iex> Mojoler.Dsl.Arith.add(20, 22)
{:ok, 42}
```

### Lists and floats

The [Mojo quickstart](https://mojolang.org/docs/manual/quickstart/) totals a list of temperatures:

```mojo
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    var total = 0.0
    for temp in temps:
        total += temp
    return total / Float64(len(temps))
```

`temps` is a read-only borrow. `total` is a local. The returned `Float64` is a new value. An empty list raises, and the caller handles it with `try` / `except`, as that tutorial does.

The NIF that sums a proper list of integers:

```elixir
iex> Mojoler.Term.list_sum([20, 22, 19, 25])
{:ok, 86}

iex> Mojoler.Term.echo_f64(22.3)
22.3
```

`list_sum/1` accepts at most 64 elements. A non-integer element is `{:error, :bad_element}`. An improper list is `{:error, :improper_list}`. `echo_f64/1` does not coerce integers.

### Transfer, from Game of Life

[Get started with Mojo](https://mojolang.org/docs/manual/get-started/) builds Conway’s Game of Life. The grid that `random_grid` builds is returned by transfer, and `evolve` swaps the current and next generation the same way:

```mojo
return grid^
```

```mojo
var tmp = self.cells^
self.cells = self.next_cells^
self.next_cells = tmp^
```

`^` ends the previous owner. The compiler rejects a use of that name until it is assigned again. The full rules are in [Value ownership and value lifecycles](docs/ownership.md).

### Notebooks

A [Mojo notebook](https://mojolang.org/docs/tools/notebooks/) cell is a whole program. The first cell loads the magic with `import mojo.notebook`. Each later cell starts with `%%mojo` and defines `main`:

```mojo
%%mojo

def main():
    print("Hello Mojo")
```

GPU cells on that page import `max.gpu.host`. They need a MAX install and a supported accelerator. Mojoler’s GPU batch is `scripts/gpu-batch.sh`. A missing MAX install exits 2 and prints `NOT RUN`.

### Binaries

Three ways to touch a binary, matching three ownership conventions:

```elixir
iex> Mojoler.Term.copy_binary(<<1, 2, 3>>)
{:ok, <<1, 2, 3>>, 3}

iex> Mojoler.Term.borrow_stable(<<1, 2, 3>>)
{:ok, 3, 1}

iex> Mojoler.Term.fill_output(4)
{:ok, <<7, 7, 7, 7>>}
```

`copy_binary/1` returns a new binary and the number of bytes copied. `borrow_stable/1` inspects the caller’s binary twice and returns the size plus `1` when both views share a data pointer. The pointer does not leave the call. `fill_output/1` writes into a binary the VM allocated for the return.

A bitstring that is not a binary is `{:error, :not_binary}`:

```elixir
iex> Mojoler.Term.copy_binary(<<1::7>>)
{:error, :not_binary}
```

### Resources

`open_blob/1` copies the bytes into a resource. Freeze transfers that buffer into a BEAM binary. After the freeze, the binary still reads `<<1, 2, 3>>` once the resource is closed.

```elixir
blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
{:ok, 3} = Mojoler.Own.blob_borrow(blob)
:ok = Mojoler.Own.blob_release(blob)
{:ok, <<1, 2, 3>>} = Mojoler.Own.blob_freeze(blob)
:ok = Mojoler.Own.blob_close(blob)
```

Freezing while a borrow is outstanding returns `{:error, :borrowed}`. A second freeze returns `{:error, :frozen}`.

## Principles

1. Elixir receives terms. A native address stays in the NIF.
2. A borrowed binary view lasts for the callback that created it.
3. Copies and transfers are separate calls.
4. CPU builds depend on Mojo. They do not import MAX.
5. One owner at a time, on both sides of the call. Mojo’s rules are [docs/ownership.md](docs/ownership.md). The BEAM half is [unit 11](docs/tutorial/11-binary-ownership.md).
