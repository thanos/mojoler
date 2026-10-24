#!/usr/bin/env python3
"""Generate Mojo OTP NIF bindings from the headers of the running ERTS.

The generator reads clang's AST and a diagnostic layout probe. It does not
link that probe into a NIF. Cross-compilation is refused: the probe runs on
the host, so its numbers are host evidence only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIN_PATH = ROOT / "tools" / "abi" / "pin.json"
FUNCTIONS_PATH = ROOT / "tools" / "abi" / "functions.txt"
OUT_MOJO = ROOT / "native" / "mojoler" / "abi" / "otp_nif.mojo"
OUT_MANIFEST = ROOT / "native" / "mojoler" / "abi" / "manifest.json"

RECORDS = (
    "enif_func_t",
    "enif_entry_t",
    "ErlNifBinary",
    "ErlNifResourceTypeInit",
    "ErlNifPid",
)

RECORD_MOJO = {
    "enif_func_t": "ErlNifFunc",
    "enif_entry_t": "ErlNifEntry",
    "ErlNifBinary": "ErlNifBinary",
    "ErlNifResourceTypeInit": "ErlNifResourceTypeInit",
    "ErlNifPid": "ErlNifPid",
}

OPAQUE = {
    "ErlNifEnv",
    "ErlNifResourceType",
    "ErlNifMutex",
    "ErlNifMapIterator",
}

ENUMS = {
    "ErlNifResourceFlags",
    "ErlNifCharEncoding",
    "ErlNifMapIteratorEntry",
    "ErlNifTimeUnit",
}

NIF_FPTR = "ERL_NIF_TERM (*)(ErlNifEnv *, int, const ERL_NIF_TERM *)"
DTOR_FPTR = "void (*)(ErlNifEnv *, void *)"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, text=True, **kwargs)


def erl_facts() -> tuple[str, str, Path]:
    code = (
        'io:format("~s|~s|~s", [erlang:system_info(otp_release), '
        'erlang:system_info(version), code:root_dir()]), halt().'
    )
    out = run(["erl", "-noshell", "-eval", code], capture_output=True).stdout.strip()
    otp, erts, root = out.split("|")
    headers = [p for p in Path(root).rglob("erl_nif.h") if p.parent.name == "include"]
    if not headers:
        raise SystemExit(f"no erl_nif.h under {root}")
    preferred = [p for p in headers if p.parts[-3:] == ("usr", "include", "erl_nif.h")]
    header = preferred[0] if preferred else headers[0]
    digest = sha256(header)
    for other in headers:
        if sha256(other) != digest:
            raise SystemExit(f"erl_nif.h copies differ: {header} vs {other}")
    return otp, erts, header


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def macros(include: Path) -> dict[str, str]:
    src = '#include "erl_nif.h"\n'
    out = run(
        ["clang", "-dM", "-E", "-I", str(include), "-x", "c", "-"],
        input=src,
        capture_output=True,
    ).stdout
    found: dict[str, str] = {}
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) >= 2 and parts[0] == "#define":
            found[parts[1]] = parts[2] if len(parts) == 3 else ""
    return found


def ast(include: Path) -> dict:
    src = '#include "erl_nif.h"\n'
    out = run(
        [
            "clang",
            "-Xclang",
            "-ast-dump=json",
            "-fsyntax-only",
            "-I",
            str(include),
            "-x",
            "c",
            "-",
        ],
        input=src,
        capture_output=True,
    ).stdout
    return json.loads(out)


def walk(node, kind: str, acc: list[dict]) -> None:
    if isinstance(node, dict):
        if node.get("kind") == kind:
            acc.append(node)
        for value in node.values():
            walk(value, kind, acc)
    elif isinstance(node, list):
        for item in node:
            walk(item, kind, acc)


def normalize(qual: str) -> str:
    text = qual.replace("const ", "").replace("volatile ", "").replace("restrict ", "")
    return " ".join(text.split())


def thin_nif() -> str:
    return (
        "def(\n"
        "        env: Pointer[NoneType, MutUntrackedOrigin],\n"
        "        argc: c_int,\n"
        "        argv: Pointer[c_ulong, MutUntrackedOrigin],\n"
        '    ) abi("C") thin -> c_ulong'
    )


def thin_dtor() -> str:
    return (
        "def(env: Pointer[NoneType, MutUntrackedOrigin], "
        "obj: Pointer[NoneType, MutUntrackedOrigin]) abi(\"C\") thin -> NoneType"
    )


def mojo_type(qual: str, *, field: str | None = None, as_param: bool = False) -> str:
    raw = " ".join(qual.split())
    if "(*)" in raw:
        if raw == NIF_FPTR:
            return thin_nif()
        if as_param and raw.replace("const ", "") == DTOR_FPTR:
            return thin_dtor()
        if as_param:
            raise SystemExit(f"unsupported function-pointer parameter: {raw}")
        # Nullable struct slots. Optional of a thin function measured 16 bytes,
        # so NULL is Optional[Pointer]. The layout probe checks the width.
        return "Optional[Pointer[NoneType, MutUntrackedOrigin]]"
    q = raw
    array = None
    if q.endswith("]") and "[" in q:
        base, rest = q.rsplit("[", 1)
        array = int(rest[:-1])
        q = base.strip()
    origin = "MutAnyOrigin" if as_param else "MutUntrackedOrigin"
    mapped = scalar(q, origin=origin)
    if array is not None:
        if not mapped.startswith("Pointer["):
            raise SystemExit(f"unsupported array field type: {qual}")
        return f"array:{array}:{mapped}"
    return mapped


def scalar(qual: str, origin: str = "MutUntrackedOrigin") -> str:
    raw = " ".join(qual.split())
    const_char = raw.startswith("const char ") or raw == "const char *"
    q = normalize(raw)
    table = {
        "int": "c_int",
        "unsigned int": "c_uint",
        "unsigned": "c_uint",
        "long": "c_long",
        "unsigned long": "c_ulong",
        "size_t": "c_size_t",
        "double": "Float64",
        "char": "c_char",
        "unsigned char": "UInt8",
        "void": "NoneType",
        "ERL_NIF_TERM": "c_ulong",
        "ERL_NIF_UINT": "c_uint",
    }
    if q in table:
        return table[q]
    if q in ENUMS:
        return "c_int"
    depth = 0
    while q.endswith("*"):
        depth += 1
        q = q[:-1].strip()
    if depth == 1 and q in {
        "ErlNifResourceDtor",
        "ErlNifResourceStop",
        "ErlNifResourceDown",
        "ErlNifResourceDynCall",
    }:
        return "Optional[Pointer[NoneType, MutUntrackedOrigin]]"
    if depth == 0:
        raise SystemExit(f"unsupported type: {qual}")
    inner = pointed(q, const_char=const_char and depth == 1, origin=origin)
    for _ in range(depth - 1):
        inner = f"Pointer[{inner}, {origin}]"
    return inner


def pointed(q: str, *, const_char: bool, origin: str) -> str:
    if q == "char":
        chosen = "ImmStaticOrigin" if const_char else origin
        return f"Pointer[c_char, {chosen}]"
    names = {
        "unsigned char": "UInt8",
        "void": "NoneType",
        "ERL_NIF_TERM": "c_ulong",
        "long": "c_long",
        "int": "c_int",
        "unsigned": "c_uint",
        "unsigned int": "c_uint",
        "unsigned long": "c_ulong",
        "double": "Float64",
        "size_t": "c_size_t",
        "ErlNifFunc": "ErlNifFunc",
        "ErlNifEntry": "ErlNifEntry",
        "ErlNifBinary": "ErlNifBinary",
        "ErlNifResourceTypeInit": "ErlNifResourceTypeInit",
        "ErlNifPid": "ErlNifPid",
        "enif_func_t": "ErlNifFunc",
        "enif_entry_t": "ErlNifEntry",
    }
    if q in OPAQUE:
        names[q] = "NoneType"
    if q in ENUMS:
        names[q] = "c_int"
    if q not in names:
        raise SystemExit(f"unsupported pointer type: {q}")
    return f"Pointer[{names[q]}, {origin}]"


FINGERPRINTS = {
    ("size", "data", "ref_bin", "__spare__"): "ErlNifBinary",
    ("pid",): "ErlNifPid",
    ("dtor", "stop", "down", "members", "dyncall"): "ErlNifResourceTypeInit",
}


def decl_fields(decl: dict, label: str) -> list[tuple[str, str]]:
    fields = []
    for child in decl.get("inner") or []:
        if child.get("kind") != "FieldDecl":
            raise SystemExit(f"{label} has unsupported member {child.get('kind')}")
        qual = child["type"]["qualType"]
        fields.append((child["name"], mojo_type(qual, field=child["name"])))
    return fields


def record_fields(tree: dict) -> dict[str, list[tuple[str, str]]]:
    decls: list[dict] = []
    walk(tree, "RecordDecl", decls)
    chosen: dict[str, list[tuple[str, str]]] = {}
    for decl in decls:
        name = decl.get("name") or ""
        raw_fields = [c for c in (decl.get("inner") or []) if c.get("kind") == "FieldDecl"]
        if not raw_fields:
            continue
        label = name or "anonymous"
        if name in RECORDS:
            fields = decl_fields(decl, label)
            if name not in chosen or len(fields) > len(chosen[name]):
                chosen[name] = fields
            continue
        fingerprint = tuple(c["name"] for c in raw_fields)
        mapped = FINGERPRINTS.get(fingerprint)
        if mapped and mapped not in chosen:
            chosen[mapped] = decl_fields(decl, mapped)
    missing = [name for name in RECORDS if name not in chosen]
    if missing:
        raise SystemExit(f"AST is missing records: {missing}")
    return chosen


def functions(tree: dict, wanted: list[str]) -> dict[str, dict]:
    decls: list[dict] = []
    walk(tree, "FunctionDecl", decls)
    found: dict[str, dict] = {}
    for decl in decls:
        name = decl.get("name")
        if name not in wanted:
            continue
        if any(child.get("kind") == "CompoundStmt" for child in decl.get("inner", [])):
            continue
        params = []
        for child in decl.get("inner", []):
            if child.get("kind") != "ParmVarDecl":
                continue
            qual = child["type"]["qualType"]
            if "..." in qual:
                raise SystemExit(f"{name} is variadic; refusing to guess a wrapper")
            params.append((child.get("name") or f"p{len(params)}", mojo_type(qual, as_param=True)))
        sig = decl["type"]["qualType"]
        if "..." in sig:
            raise SystemExit(f"{name} is variadic; refusing to guess a wrapper")
        ret = sig.split("(", 1)[0].strip()
        found[name] = {"ret": mojo_type(ret), "params": params, "sig": sig}
    missing = [name for name in wanted if name not in found]
    if missing:
        raise SystemExit("AST is missing functions:\n" + "\n".join(missing))
    return found


def safe_ident(name: str) -> str:
    cleaned = name.strip("_") or "field"
    if name.startswith("_"):
        cleaned = "spare" if "spare" in name else cleaned
    if cleaned in {"type", "len", "object", "from", "alias", "struct", "def", "var"}:
        cleaned = "arg_" + cleaned
    return cleaned


def emit_struct(mojo_name: str, fields: list[tuple[str, str]]) -> str:
    lines = ["@fieldwise_init", f"struct {mojo_name}(RegisterPassable):"]
    for name, typ in fields:
        ident = safe_ident(name)
        if typ.startswith("array:"):
            count = int(typ.split(":")[1])
            inner = typ.split(":", 2)[2]
            for i in range(count):
                lines.append(f"    var {ident}_{i}: {inner}")
        elif "\n" in typ:
            lines.append(f"    var {ident}: {typ}")
        else:
            lines.append(f"    var {ident}: {typ}")
    return "\n".join(lines)


TYPE_ALIASES = (
    ("Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin]", "EnvPtrPtr"),
    ("Pointer[Pointer[c_ulong, MutUntrackedOrigin], MutUntrackedOrigin]", "TermPtrPtr"),
    ("Optional[Pointer[NoneType, MutUntrackedOrigin]]", "OptPtr"),
    ("Pointer[NoneType, MutUntrackedOrigin]", "EnvPtr"),
    ("Pointer[UInt8, MutUntrackedOrigin]", "BytePtr"),
    ("Pointer[ErlNifPid, MutUntrackedOrigin]", "PidPtr"),
    ("Pointer[ErlNifBinary, MutUntrackedOrigin]", "BinPtr"),
    ("Pointer[ErlNifFunc, MutUntrackedOrigin]", "FuncPtr"),
    ("Pointer[c_char, MutUntrackedOrigin]", "CharMut"),
    ("Pointer[c_char, ImmStaticOrigin]", "CharImm"),
    ("Pointer[c_long, MutUntrackedOrigin]", "LongPtr"),
    ("Pointer[c_ulong, MutUntrackedOrigin]", "ULongPtr"),
    ("Pointer[c_int, MutUntrackedOrigin]", "IntPtr"),
    ("Pointer[c_uint, MutUntrackedOrigin]", "UIntPtr"),
    ("Pointer[c_size_t, MutUntrackedOrigin]", "SizePtr"),
    ("Pointer[Float64, MutUntrackedOrigin]", "F64Ptr"),
)


def call_type(typ: str) -> str:
    # Mojo 1.1.0 rejects file-scope `alias`, so wrappers spell the type.
    # Nested brackets keep the comma inside the type, which external_call accepts.
    return typ


def emit_func(name: str, spec: dict) -> str:
    params = []
    arg_names = []
    origins = []
    for index, (pname, typ) in enumerate(spec["params"]):
        if "\n" in typ:
            raise SystemExit(f"{name} parameter {pname} has a multi-line type")
        ident = safe_ident(pname)
        if "MutAnyOrigin" in typ or "MutUntrackedOrigin" in typ:
            origin = f"o{index}"
            origins.append(origin)
            typ = typ.replace("MutAnyOrigin", origin).replace("MutUntrackedOrigin", origin)
        arg_names.append(ident)
        params.append(f"{ident}: {call_type(typ)}")
    ret = spec["ret"]
    called = call_type(ret)
    generic = ""
    if origins:
        generic = "[" + ", ".join(f"{origin}: Origin" for origin in origins) + "]"
    if ret == "NoneType":
        head = f"def {name}{generic}({', '.join(params)}):"
        body = f'    external_call["{name}", {called}]({", ".join(arg_names)})'
    else:
        head = f"def {name}{generic}({', '.join(params)}) -> {called}:"
        body = f'    return external_call["{name}", {called}]({", ".join(arg_names)})'
    return head + "\n" + body


def enum_value(tree: dict, name: str) -> int:
    decls: list[dict] = []
    walk(tree, "EnumConstantDecl", decls)
    for decl in decls:
        if decl.get("name") != name:
            continue
        for child in decl.get("inner") or []:
            if child.get("kind") == "ConstantExpr" and "value" in child:
                return int(child["value"])
    raise SystemExit(f"AST has no value for enum {name}")


def render(header_hash: str, defs: dict[str, str], fields: dict, funcs: dict[str, dict], map_iter_size: int, dirty_cpu: int, dirty_io: int) -> str:
    major = int(defs["ERL_NIF_MAJOR_VERSION"])
    minor = int(defs["ERL_NIF_MINOR_VERSION"])
    vm = defs["ERL_NIF_VM_VARIANT"].strip('"')
    min_erts = defs["ERL_NIF_MIN_ERTS_VERSION"].strip('"')
    aliases = []
    for key in ("enif_get_int64", "enif_make_int64", "enif_get_uint64", "enif_make_uint64"):
        if key in defs:
            aliases.append(f"# {key} -> {defs[key]}")
    parts = [
        "# Generated by tools/abi/generate.py. Do not edit.",
        f"# header_sha256: {header_hash}",
        "# Cross-compilation is unsupported. These declarations match the host headers.",
        "",
        "from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong, external_call",
        "",
        "def abi_major() -> c_int:",
        f"    return c_int({major})",
        "",
        "def abi_minor() -> c_int:",
        f"    return c_int({minor})",
        "",
        "def abi_options() -> c_uint:",
        "    return c_uint(1)",
        "",
        "def abi_dirty_cpu() -> c_uint:",
        f"    return c_uint({dirty_cpu})",
        "",
        "def abi_dirty_io() -> c_uint:",
        f"    return c_uint({dirty_io})",
        "",
        "def abi_map_iter_size() -> c_size_t:",
        f"    return c_size_t({map_iter_size})",
        "",
        "def abi_vm_variant() -> Pointer[c_char, ImmStaticOrigin]:",
        f'    return "{vm}".as_c_string_span().ptr()',
        "",
        "def abi_min_erts() -> Pointer[c_char, ImmStaticOrigin]:",
        f'    return "{min_erts}".as_c_string_span().ptr()',
        "",
        *aliases,
        "",
    ]
    for c_name, mojo_name in RECORD_MOJO.items():
        parts.append(emit_struct(mojo_name, fields[c_name]))
        parts.append("")
    parts.append("")
    for name in sorted(funcs):
        parts.append(emit_func(name, funcs[name]))
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def probe_map_iter(include: Path) -> int:
    src = r"""
#include "erl_nif.h"
#include <stdio.h>
int main(void) {
    printf("%zu\n", sizeof(ErlNifMapIterator));
    return 0;
}
"""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "probe"
        run(["clang", "-I", str(include), "-x", "c", "-", "-o", str(path)], input=src)
        out = run([str(path)], capture_output=True).stdout.strip()
    return int(out)


def build(target_triple: str | None) -> tuple[str, dict]:
    pin = json.loads(PIN_PATH.read_text())
    host = run(["clang", "-dumpmachine"], capture_output=True).stdout.strip()
    if target_triple and target_triple != host:
        raise SystemExit(
            f"cross-compilation is unsupported: requested {target_triple}, host is {host}"
        )
    otp, erts, header = erl_facts()
    include = header.parent
    if otp != pin["otp_release"] or erts != pin["erts"]:
        raise SystemExit(f"refusing OTP {otp} erts {erts}; pin is {pin['otp_release']} {pin['erts']}")
    defs = macros(include)
    if defs.get("SIZEOF_LONG") != str(pin["sizeof_long"]):
        raise SystemExit(f"SIZEOF_LONG is {defs.get('SIZEOF_LONG')}, pin requires {pin['sizeof_long']}")
    if int(defs["ERL_NIF_MAJOR_VERSION"]) != pin["nif_major"] or int(defs["ERL_NIF_MINOR_VERSION"]) != pin["nif_minor"]:
        raise SystemExit("NIF version does not match tools/abi/pin.json")
    endian = "little" if sys.byteorder == "little" else "big"
    if endian != pin["endian"] or platform.architecture()[0] != "64bit":
        raise SystemExit(f"refusing endian/width {endian} {platform.architecture()}")
    tree = ast(include)
    wanted = [line.strip() for line in FUNCTIONS_PATH.read_text().splitlines() if line.strip()]
    fields = record_fields(tree)
    funcs = functions(tree, wanted)
    header_hash = sha256(header)
    api_hash = sha256(include / "erl_nif_api_funcs.h")
    map_iter = probe_map_iter(include)
    dirty_cpu = enum_value(tree, "ERL_NIF_DIRTY_JOB_CPU_BOUND")
    dirty_io = enum_value(tree, "ERL_NIF_DIRTY_JOB_IO_BOUND")
    text = render(header_hash, defs, fields, funcs, map_iter, dirty_cpu, dirty_io)
    manifest = {
        "generator": 1,
        "host_triple": host,
        "otp_release": otp,
        "erts": erts,
        "nif_major": int(defs["ERL_NIF_MAJOR_VERSION"]),
        "nif_minor": int(defs["ERL_NIF_MINOR_VERSION"]),
        "sizeof_long": int(defs["SIZEOF_LONG"]),
        "endian": endian,
        "pointer_bits": 64,
        "vm_variant": defs["ERL_NIF_VM_VARIANT"].strip('"'),
        "min_erts": defs["ERL_NIF_MIN_ERTS_VERSION"].strip('"'),
        "dirty_cpu": dirty_cpu,
        "dirty_io": dirty_io,
        "header_sha256": header_hash,
        "api_header_sha256": api_hash,
        "clang": run(["clang", "--version"], capture_output=True).stdout.splitlines()[0],
        "macro_aliases": {
            key: defs[key]
            for key in ("enif_get_int64", "enif_make_int64", "enif_get_uint64", "enif_make_uint64")
            if key in defs
        },
        "functions": wanted,
        "map_iterator_bytes": map_iter,
        "cross_compilation": "unsupported",
    }
    return text, manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--target-triple", default=None)
    args = parser.parse_args()
    text, manifest = build(args.target_triple)
    blob = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if args.check:
        current = OUT_MOJO.read_text() if OUT_MOJO.exists() else ""
        if current != text:
            raise SystemExit("generated Mojo is stale; run tools/abi/generate.py")
        print("abi mojo: matches")
        return
    OUT_MOJO.parent.mkdir(parents=True, exist_ok=True)
    OUT_MOJO.write_text(text)
    OUT_MANIFEST.write_text(blob)
    print(f"wrote {OUT_MOJO}")
    print(f"wrote {OUT_MANIFEST}")


if __name__ == "__main__":
    main()
