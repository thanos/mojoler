#!/usr/bin/env bash
# Report whether this machine can build and load the Stage 0 NIF.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=env.sh
source "$root/scripts/env.sh"
fail=0

note() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

os="$(uname -s)"
arch="$(uname -m)"
if [[ "$os" == "Darwin" && "$arch" == "arm64" ]]; then
  note "platform Darwin arm64 $(sw_vers -productVersion)"
elif [[ "$os" == "Linux" && "$arch" == "x86_64" ]]; then
  note "platform Linux x86_64"
else
  bad "platform is ${os} ${arch}; Stage 0 runs on Darwin arm64 or Linux x86_64"
fi

tools=(elixir erl mix nm)
if [[ "$os" == "Darwin" ]]; then
  tools+=(otool)
else
  tools+=(ldd)
fi
if [[ -n "$CC_TOOL" ]]; then
  tools+=("$CC_TOOL")
else
  bad "missing cc or clang — the layout diagnostic needs a C compiler"
fi

for cmd in "${tools[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    case "$cmd" in
      elixir) note "elixir $(elixir --version 2>&1 | awk '/Elixir/ {print $2}')" ;;
      erl)
        ver="$(erl -noshell -eval 'io:format("~s erts-~s",[erlang:system_info(otp_release), erlang:system_info(version)]), halt().')"
        note "erlang $ver"
        ;;
      mix) note "mix $(mix --version 2>&1 | awk '/Mix/ {print $2}')" ;;
      clang|cc|gcc) note "$cmd $($cmd --version 2>&1 | head -1)" ;;
      *) note "$cmd $(command -v "$cmd")" ;;
    esac
  else
    bad "missing $cmd"
  fi
done

mojo="$root/.venv/bin/mojo"
if [[ -x "$mojo" ]]; then
  note "mojo $($mojo --version 2>&1)"
else
  bad "missing $mojo — from the repo root run: uv venv && uv pip install -r requirements.txt"
fi

if [[ -n "$ERL_NIF_H" && -f "$ERL_NIF_H" ]]; then
  note "erl_nif.h $ERL_NIF_H"
else
  bad "erl_nif.h not found under code:root_dir() — install erlang 28.3.1 (see .tool-versions)"
fi

kgen="$(find "$root/.venv" \( -name 'libKGENCompilerRTShared.dylib' -o -name 'libKGENCompilerRTShared.so' \) -print -quit 2>/dev/null || true)"
if [[ -n "$kgen" && -f "$kgen" ]]; then
  note "mojo runtime $kgen"
else
  bad "missing libKGENCompilerRTShared next to the mojo package"
fi

if [[ "$fail" -ne 0 ]]; then
  printf '\ndoctor: prerequisites missing\n'
  exit 1
fi

printf '\ndoctor: ready\n'
