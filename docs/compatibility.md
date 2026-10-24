# Compatibility

| Piece | Supported | Evidence | Not supported |
| --- | --- | --- | --- |
| OTP 28.3.1, erts 16.2, NIF 2.17 | yes | doctor, E1, E18 | other minors |
| Elixir 1.20.2 | yes | doctor | other Elixir |
| Mojo 1.1.0 (`8189361e`) | yes | doctor | nightly, `fn`, file-scope `alias` |
| Darwin arm64 | yes | E20–E26 | Intel Mac, iOS |
| Linux x86-64, Ubuntu 24.04 | Stage 0 CPU yes | E18, E19 | stages 1–10 until the new workflow runs |
| Windows | no | generator refuses a non-host triple | |
| Apple GPU, MAX 26.6.0 | one call and a 4-wide batch | E17, E25 | no-device not observed |
| NVIDIA, Linux GPU | no | not run | a CPU result does not count |

`tools/abi/pin.json` requires OTP 28, erts 16.2, NIF 2.17, 64-bit little-endian, `SIZEOF_LONG` 8. The generator exits if the host headers disagree. Identical pointer width is not treated as a port.
