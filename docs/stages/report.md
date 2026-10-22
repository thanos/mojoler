# Stage report

Commands below were run on this Mac (Darwin arm64, macOS 26.5, Apple clang 17, OTP 28.3.1, Elixir 1.20.2, Mojo 1.1.0 `8189361e`). Linux CPU for Stage 0 remains E18 and E19 at commit `e6728ea`. The updated workflow has not run.

| Stage | This Mac | Linux CPU | Other |
| --- | --- | --- | --- |
| 0 add/2 | PASS (still in the 43) | PASS (E19, 11 tests) | |
| 1 ABI | PASS (E20) | PENDING | cross-compile refused |
| 2 terms | PASS | PENDING | NaN term not constructible here |
| 3 ownership | PASS | PENDING | upgrade callback not invoked |
| 4 schedulers | PASS (E22, dirty 18 / normal 0) | PENDING | no cancellation |
| 5 Mix | PASS (E23, release 42) | PENDING | KGEN not bundled |
| 6 DSL | PASS | PENDING | |
| 7 demos | PASS (E24) | PENDING | `warm_add_us 4` is one sample |
| 8 GPU | PASS for 42 and batch 110 (E25) | NOT RUN | NVIDIA NOT RUN; no-device NOT OBSERVED |
| 9 CI | workflow written | PENDING | no macOS runner |
| 10 release | local candidate PASS | PENDING | not published |

Ownership that was shown: borrowed inspect without returning a pointer, explicit payload copy with a byte count, OTP-allocated output, a resource binary after freeze, a pin that delays the destructor, a retained env that survives its process.

Scheduling that was shown: generated flags 1 and 2, dirty CPU heartbeats on one scheduler, a normal-scheduler control with zero heartbeats, and a yield that does not stop the burn.

Next actions for anything that is not PASS:

1. Push and read the Ubuntu log before calling Linux CPU PASS for stages 1–10.
2. Run `scripts/gpu-batch.sh` on a machine with no accelerator if the `no_device` tuple needs a row.
3. Do not add an Intel Mac runner and label it ARM64.
4. NVIDIA stays NOT RUN until a machine with that device runs a separate script and records the driver.
