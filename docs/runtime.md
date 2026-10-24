# Runtime packaging

CPU libraries link with the flags in `scripts/env.sh`. On Darwin that is `-undefined dynamic_lookup`. On Linux it is `--unresolved-symbols=ignore-all` and `-z undefs`. `enif_*` symbols stay undefined until `beam.smp` loads the file.

Darwin `otool -L` on these libraries lists `@rpath/libKGENCompilerRTShared.dylib` and an rpath into the venv's `modular/lib`. Linux Stage 0 `libpoc.so` did not `DT_NEEDED` that library (E19). Later Linux libraries have not been inspected.

This repo does not copy KGEN into a release. The license question was not settled, so the prerequisite is: Mojo 1.1.0 is installed, and the dynamic loader can see the runtime the build recorded. `scripts/release-candidate.sh` passed on this Mac because that venv was still on disk. Moving the release to a machine without that runtime is untested and should be expected to fail at `dlopen` until the rpath or `DYLD_LIBRARY_PATH` / `LD_LIBRARY_PATH` is set on purpose.

CPU consumers install `requirements.txt` only. `requirements-gpu.txt` is the MAX pin for `scripts/gpu-batch.sh`. A CPU `mix test` does not import `max`.

`load_nif` appends `.so` on Darwin and on Linux. The Mix compiler publishes `priv/native/lib<name>.so` by rename. It will not rename over a library this VM has already loaded.

Unload of `Mojoler.Own` frees the private type box. It does not free the NIF entry. See [stages/s1.md](stages/s1.md).
