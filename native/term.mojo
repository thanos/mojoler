# Checked term conversions for Elixir.Mojoler.Term.
# Raw enif calls stay in the generated ABI module. This file checks ranges,
# sizes, and UTF-8 before it touches a payload.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong
from std.sys import size_of

from mojoler.abi.otp_nif import (
    ErlNifBinary,
    ErlNifEntry,
    ErlNifFunc,
    abi_dirty_cpu,
    enif_alloc,
    enif_alloc_binary,
    enif_free,
    enif_get_atom,
    enif_get_double,
    enif_get_int,
    enif_get_list_cell,
    enif_get_list_length,
    enif_get_long,
    enif_get_map_value,
    enif_get_tuple,
    enif_get_uint,
    enif_get_ulong,
    enif_inspect_binary,
    enif_is_list,
    enif_make_atom,
    enif_make_badarg,
    enif_make_binary,
    enif_make_double,
    enif_make_int,
    enif_make_list_cell,
    enif_make_long,
    enif_make_map_put,
    enif_make_new_binary,
    enif_make_new_map,
    enif_make_tuple_from_array,
    enif_make_uint,
    enif_make_ulong,
    enif_release_binary,
)
from mojoler.abi.prim import alloc_funcs, make_entry, must_alloc, must_free

# Caps for work that still runs on a normal scheduler. Stage 4 moves long jobs.
# 64 64, 1048576 1048576, UTF-8 encoding value 2.


def lit(text: StaticString) -> Pointer[c_char, ImmStaticOrigin]:
    return text.as_c_string_span().ptr()


def atom(env: Pointer[NoneType, MutUntrackedOrigin], name: StaticString) -> c_ulong:
    # Fixed vocabulary only. User bytes never reach enif_make_atom.
    return enif_make_atom(env, lit(name))


def bad(env: Pointer[NoneType, MutUntrackedOrigin]) -> c_ulong:
    return enif_make_badarg(env)


def pair(env: Pointer[NoneType, MutUntrackedOrigin], a: c_ulong, b: c_ulong) -> c_ulong:
    var mem = enif_alloc(c_size_t(16))
    var arr = mem.unsafe_bitcast[c_ulong]()
    arr[unsafe_offset=0] = a
    arr[unsafe_offset=1] = b
    var out = enif_make_tuple_from_array(env, arr, c_uint(2))
    enif_free(mem)
    return out


def triple(env: Pointer[NoneType, MutUntrackedOrigin], a: c_ulong, b: c_ulong, c: c_ulong) -> c_ulong:
    var mem = enif_alloc(c_size_t(24))
    var arr = mem.unsafe_bitcast[c_ulong]()
    arr[unsafe_offset=0] = a
    arr[unsafe_offset=1] = b
    arr[unsafe_offset=2] = c
    var out = enif_make_tuple_from_array(env, arr, c_uint(3))
    enif_free(mem)
    return out


def ok(env: Pointer[NoneType, MutUntrackedOrigin], value: c_ulong) -> c_ulong:
    return pair(env, atom(env, "ok"), value)


def err(env: Pointer[NoneType, MutUntrackedOrigin], name: StaticString) -> c_ulong:
    return pair(env, atom(env, "error"), atom(env, name))


def fits_int64(a: c_long, b: c_long) -> Bool:
    comptime maxv = c_long(9223372036854775807)
    comptime min_mag = c_long(9223372036854775807)
    if b > 0 and a > (maxv - b):
        return False
    if b < 0:
        if a < 0 and (b + min_mag) == -1:
            return False
        var limit = (c_long(0) - min_mag - c_long(1)) - b
        if a < limit:
            return False
    return True


def echo_i64(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=0], Pointer(to=n)) == 0:
        return bad(env)
    return enif_make_long(env, n)


def echo_u64(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = c_ulong(0)
    if enif_get_ulong(env, argv[unsafe_offset=0], Pointer(to=n)) == 0:
        return bad(env)
    return enif_make_ulong(env, n)


def echo_i32(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = c_int(0)
    if enif_get_int(env, argv[unsafe_offset=0], Pointer(to=n)) == 0:
        return bad(env)
    return enif_make_int(env, n)


def echo_u32(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = c_uint(0)
    if enif_get_uint(env, argv[unsafe_offset=0], Pointer(to=n)) == 0:
        return bad(env)
    return enif_make_uint(env, n)


def add_i64(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 2:
        return bad(env)
    var a = c_long(0)
    var b = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=0], Pointer(to=a)) == 0:
        return bad(env)
    if enif_get_long(env, argv[unsafe_offset=1], Pointer(to=b)) == 0:
        return bad(env)
    if not fits_int64(a, b):
        return err(env, "overflow")
    return ok(env, enif_make_long(env, a + b))


def echo_f64(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = Float64(0)
    if enif_get_double(env, argv[unsafe_offset=0], Pointer(to=n)) == 0:
        return bad(env)
    if n != n:
        return err(env, "nan")
    return enif_make_double(env, n)


def same_atom(env: Pointer[NoneType, MutUntrackedOrigin], term: c_ulong, name: StaticString) -> Bool:
    var buf = must_alloc(c_size_t(16))
    var n = name.byte_length()
    if n > 15:
        must_free(buf)
        return False
    var written = enif_get_atom(env, term, buf.unsafe_bitcast[c_char](), c_uint(16), c_int(2))
    if written == 0:
        must_free(buf)
        return False
    var raw = name.as_bytes()
    var i = 0
    var eq = True
    while i < n:
        if Int(buf[unsafe_offset=i]) != Int(raw[i]):
            eq = False
        i += 1
    if Int(buf[unsafe_offset=n]) != 0:
        eq = False
    must_free(buf)
    return eq


def echo_atom(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var names = StaticString("ok,error,nil,true,false")
    _ = names
    if same_atom(env, argv[unsafe_offset=0], "ok"):
        return atom(env, "ok")
    if same_atom(env, argv[unsafe_offset=0], "error"):
        return atom(env, "error")
    if same_atom(env, argv[unsafe_offset=0], "nil"):
        return atom(env, "nil")
    if same_atom(env, argv[unsafe_offset=0], "true"):
        return atom(env, "true")
    if same_atom(env, argv[unsafe_offset=0], "false"):
        return atom(env, "false")
    return err(env, "unknown_atom")


def inspect(
    env: Pointer[NoneType, MutUntrackedOrigin], term: c_ulong
) -> Optional[Pointer[ErlNifBinary, MutUntrackedOrigin]]:
    var mem = must_alloc(c_size_t(size_of[ErlNifBinary]()))
    var bin = mem.unsafe_bitcast[ErlNifBinary]()
    if enif_inspect_binary(env, term, bin) == 0:
        must_free(mem)
        return None
    return bin


def copy_binary(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var src_opt = inspect(env, argv[unsafe_offset=0])
    if not src_opt:
        return err(env, "not_binary")
    var src = src_opt.value()
    var nbytes = Int(src[].size)
    if nbytes > 1048576:
        must_free(src)
        return err(env, "too_large")
    var dst_mem = must_alloc(c_size_t(size_of[ErlNifBinary]()))
    var dst = dst_mem.unsafe_bitcast[ErlNifBinary]()
    if enif_alloc_binary(src[].size, dst) == 0:
        must_free(src)
        must_free(dst_mem)
        return err(env, "alloc")
    var i = 0
    while i < nbytes:
        dst[].data[unsafe_offset=i] = src[].data[unsafe_offset=i]
        i += 1
    var out = enif_make_binary(env, dst)
    must_free(src)
    must_free(dst_mem)
    return triple(env, atom(env, "ok"), out, enif_make_long(env, c_long(nbytes)))


def borrow_stable(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var a_opt = inspect(env, argv[unsafe_offset=0])
    var b_opt = inspect(env, argv[unsafe_offset=0])
    if not a_opt or not b_opt:
        if a_opt:
            must_free(a_opt.value())
        if b_opt:
            must_free(b_opt.value())
        return err(env, "not_binary")
    var a = a_opt.value()
    var b = b_opt.value()
    var same = Int(a[].data) == Int(b[].data)
    var size = Int(a[].size)
    must_free(a)
    must_free(b)
    var flag = 0
    if same:
        flag = 1
    return triple(env, atom(env, "ok"), enif_make_long(env, c_long(size)), enif_make_long(env, c_long(flag)))


def fill_output(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var n = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=0], Pointer(to=n)) == 0 or n < 0 or n > 1048576:
        return err(env, "bad_size")
    var term = c_ulong(0)
    var dst = enif_make_new_binary(env, c_size_t(n), Pointer(to=term))
    var i = 0
    while i < Int(n):
        dst[unsafe_offset=i] = UInt8(7)
        i += 1
    return pair(env, atom(env, "ok"), term)


def utf8_ok(data: Pointer[UInt8, MutUntrackedOrigin], n: Int) -> Bool:
    var i = 0
    while i < n:
        var b = Int(data[unsafe_offset=i])
        var need = 0
        if b < 0x80:
            need = 1
        elif b >= 0xC2 and b <= 0xDF:
            need = 2
        elif b == 0xE0 or (b >= 0xE1 and b <= 0xEC) or b == 0xED or (b >= 0xEE and b <= 0xEF):
            need = 3
        elif b >= 0xF0 and b <= 0xF4:
            need = 4
        else:
            return False
        if i + need > n:
            return False
        var j = 1
        while j < need:
            var c = Int(data[unsafe_offset=i + j])
            if c < 0x80 or c > 0xBF:
                return False
            j += 1
        i += need
    return True


def text_len(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var src_opt = inspect(env, argv[unsafe_offset=0])
    if not src_opt:
        return err(env, "not_binary")
    var src = src_opt.value()
    var n = Int(src[].size)
    var good = utf8_ok(src[].data, n)
    must_free(src)
    if not good:
        return err(env, "invalid_utf8")
    return ok(env, enif_make_long(env, c_long(n)))


def tuple_sum(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var arity = c_int(0)
    var slot = must_alloc(c_size_t(8))
    var array_box = slot.unsafe_bitcast[Pointer[c_ulong, MutUntrackedOrigin]]()
    if enif_get_tuple(env, argv[unsafe_offset=0], Pointer(to=arity), array_box) == 0:
        must_free(slot)
        return err(env, "not_tuple")
    var array = array_box[]
    must_free(slot)
    if arity != 2:
        return err(env, "bad_arity")
    var a = c_long(0)
    var b = c_long(0)
    if enif_get_long(env, array[unsafe_offset=0], Pointer(to=a)) == 0:
        return err(env, "bad_element")
    if enif_get_long(env, array[unsafe_offset=1], Pointer(to=b)) == 0:
        return err(env, "bad_element")
    if not fits_int64(a, b):
        return err(env, "overflow")
    return ok(env, enif_make_long(env, a + b))


def list_sum(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var length = c_uint(0)
    if enif_is_list(env, argv[unsafe_offset=0]) == 0:
        return err(env, "not_list")
    if enif_get_list_length(env, argv[unsafe_offset=0], Pointer(to=length)) == 0:
        return err(env, "improper_list")
    if Int(length) > 64:
        return err(env, "too_long")
    var cell = argv[unsafe_offset=0]
    var acc = c_long(0)
    var seen = 0
    while seen < Int(length):
        var head = c_ulong(0)
        var tail = c_ulong(0)
        if enif_get_list_cell(env, cell, Pointer(to=head), Pointer(to=tail)) == 0:
            return err(env, "improper_list")
        var n = c_long(0)
        if enif_get_long(env, head, Pointer(to=n)) == 0:
            return err(env, "bad_element")
        if not fits_int64(acc, n):
            return err(env, "overflow")
        acc = acc + n
        cell = tail
        seen += 1
    return ok(env, enif_make_long(env, acc))


def map_n(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var key = atom(env, "n")
    var value = c_ulong(0)
    if enif_get_map_value(env, argv[unsafe_offset=0], key, Pointer(to=value)) == 0:
        return err(env, "missing")
    var n = c_long(0)
    if enif_get_long(env, value, Pointer(to=n)) == 0:
        return err(env, "bad_element")
    var built = enif_make_new_map(env)
    var out = c_ulong(0)
    if enif_make_map_put(env, built, key, enif_make_long(env, n), Pointer(to=out)) == 0:
        return err(env, "map")
    return ok(env, out)


def put(funcs: Pointer[ErlNifFunc, MutUntrackedOrigin], i: Int, name: StaticString, arity: Int, f: def(env: Pointer[NoneType, MutUntrackedOrigin], argc: c_int, argv: Pointer[c_ulong, MutUntrackedOrigin]) abi("C") thin -> c_ulong, flags: c_uint):
    funcs[unsafe_offset=i] = ErlNifFunc(lit(name), c_uint(arity), f, flags)


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    _ = abi_dirty_cpu()
    var funcs = alloc_funcs(14)
    put(funcs, 0, "echo_i64", 1, echo_i64, c_uint(0))
    put(funcs, 1, "echo_u64", 1, echo_u64, c_uint(0))
    put(funcs, 2, "echo_i32", 1, echo_i32, c_uint(0))
    put(funcs, 3, "echo_u32", 1, echo_u32, c_uint(0))
    put(funcs, 4, "add_i64", 2, add_i64, c_uint(0))
    put(funcs, 5, "echo_f64", 1, echo_f64, c_uint(0))
    put(funcs, 6, "echo_atom", 1, echo_atom, c_uint(0))
    put(funcs, 7, "copy_binary", 1, copy_binary, c_uint(0))
    put(funcs, 8, "borrow_stable", 1, borrow_stable, c_uint(0))
    put(funcs, 9, "fill_output", 1, fill_output, c_uint(0))
    put(funcs, 10, "text_len", 1, text_len, c_uint(0))
    put(funcs, 11, "tuple_sum", 1, tuple_sum, c_uint(0))
    put(funcs, 12, "list_sum", 1, list_sum, c_uint(0))
    put(funcs, 13, "map_n", 1, map_n, c_uint(0))
    return make_entry(lit("Elixir.Mojoler.Term"), funcs, c_int(14), None, None, None, None)
