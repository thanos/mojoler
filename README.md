# Mojoler

Mojoler is a Stage 0 proof that an Erlang NIF can be written in Mojo and loaded by the BEAM without a C or C++ implementation file.

On this machine the proof passes:

```elixir
Mojoler.POC.add(20, 22) == 42
```

The native code is [native/poc.mojo](native/poc.mojo). The Elixir stub is [lib/mojoler/poc.ex](lib/mojoler/poc.ex). The verdict, the limits, and the tutorial are in [docs/](docs/TUTORIAL.md).

## Platform

Tested on macOS 26.5, Apple silicon, and on Linux x86-64 (`ubuntu-24.04` in GitHub Actions). Both used OTP 28.3.1 (erts 16.2), Elixir 1.20.2, and Mojo 1.1.0 (`8189361e`). A separate one-element Apple GPU add, MAX 26.6.0, also returned 42 on this Mac. The Linux job has no GPU.

## Setup

```sh
uv venv && uv pip install -r requirements.txt
scripts/doctor.sh
scripts/test-isolated.sh
```

`.tool-versions` selects Erlang 28.3.1 and Elixir 1.20.2-otp-28. `scripts/test-isolated.sh` rebuilds `priv/native/libpoc.so` and runs ExUnit under a 180 second alarm.

The `linux` GitHub Actions workflow runs that same CPU check on Ubuntu 24.04. [Run 39451722783](https://github.com/thanos/mojoler/actions/runs/39451722783) finished with `11 passed`. It does not have a GPU.

## What is deliberately absent

No handwritten C or C++ is linked into the NIF. [experiments/abi/diagnostic/layout.c](experiments/abi/diagnostic/layout.c) only prints struct offsets and is not an input to [scripts/build-native.sh](scripts/build-native.sh).
