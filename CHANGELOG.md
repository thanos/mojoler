# Changelog

## 0.1.0

First Hex release.

* `Mojoler.POC.add/2` is checked signed 64-bit addition.
* Generated OTP 28 ABI, checked term conversions, resources, and dirty-CPU scheduling.
* `Mix.Tasks.Compile.Mojoler` builds the `.so` files. `mojo` is taken from the project `.venv` or from `PATH`.
* The Mojo runtime is not included. CPU consumers do not need MAX.
* Pinned development target: Elixir 1.20.2, OTP 28.3.1, Mojo 1.1.0. Other OTP majors are refused by the ABI pin.
* Credo runs in strict mode. Test coverage is published to Coveralls from the Linux workflow.
