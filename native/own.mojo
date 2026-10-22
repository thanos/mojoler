# Resources, retained terms, and native buffers for Elixir.Mojoler.Own.
# Destructors send a message and free only the allocator they paired with.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong, external_call
from std.sys import size_of

from mojoler.abi.otp_nif import (
    ErlNifEntry,
    ErlNifFunc,
    ErlNifPid,
    enif_alloc_env,
    enif_alloc_resource,
    enif_free_env,
    enif_get_long,
    enif_get_resource,
    enif_inspect_binary,
    enif_keep_resource,
    enif_make_atom,
    enif_make_badarg,
    enif_make_copy,
    enif_make_long,
    enif_make_resource,
    enif_make_resource_binary,
    enif_make_tuple_from_array,
    enif_mutex_create,
    enif_mutex_destroy,
    enif_mutex_lock,
    enif_mutex_unlock,
    enif_priv_data,
    enif_release_resource,
    enif_self,
    enif_send,
)
from mojoler.abi.prim import alloc_funcs, callback_opt, make_entry, must_alloc, must_free

from mojoler.abi.otp_nif import ErlNifBinary


@fieldwise_init
struct Types(RegisterPassable):
    var counter: Pointer[NoneType, MutUntrackedOrigin]
    var blob: Pointer[NoneType, MutUntrackedOrigin]
    var retained: Pointer[NoneType, MutUntrackedOrigin]
    var pin: Pointer[NoneType, MutUntrackedOrigin]
    var lock: Pointer[NoneType, MutUntrackedOrigin]
    var blob_dtors: c_long
    var next_token: c_long


@fieldwise_init
struct Counter(RegisterPassable):
    var value: c_long
    var closed: c_long
    var pid: ErlNifPid


@fieldwise_init
struct Blob(RegisterPassable):
    var data: Pointer[UInt8, MutUntrackedOrigin]
    var size: c_long
    var borrows: c_long
    var frozen: c_long
    var closed: c_long
    var token: c_long


@fieldwise_init
struct Retained(RegisterPassable):
    var env: Pointer[NoneType, MutUntrackedOrigin]
    var term: c_ulong


@fieldwise_init
struct Pin(RegisterPassable):
    var obj: Pointer[NoneType, MutUntrackedOrigin]


def lit(text: StaticString) -> Pointer[c_char, ImmStaticOrigin]:
    return text.as_c_string_span().ptr()


def types(env: Pointer[NoneType, MutUntrackedOrigin]) -> Pointer[Types, MutUntrackedOrigin]:
    return enif_priv_data(env).unsafe_bitcast[Types]()


def send_atom(
    env: Pointer[NoneType, MutUntrackedOrigin],
    pid: Pointer[ErlNifPid, MutUntrackedOrigin],
    name: StaticString,
):
    var msg_env = enif_alloc_env()
    var msg = enif_make_atom(msg_env, lit(name))
    _ = enif_send(env, pid, msg_env, msg)
    enif_free_env(msg_env)


def counter_dtor(
    env: Pointer[NoneType, MutUntrackedOrigin], obj: Pointer[NoneType, MutUntrackedOrigin]
) abi("C"):
    var body = obj.unsafe_bitcast[Counter]()
    send_atom(env, Pointer(to=body[].pid), "counter_destroyed")


def blob_dtor(
    env: Pointer[NoneType, MutUntrackedOrigin], obj: Pointer[NoneType, MutUntrackedOrigin]
) abi("C"):
    var info = types(env)
    enif_mutex_lock(info[].lock)
    info[].blob_dtors = info[].blob_dtors + c_long(1)
    enif_mutex_unlock(info[].lock)
    var body = obj.unsafe_bitcast[Blob]()
    must_free(body[].data)


def pin_dtor(
    env: Pointer[NoneType, MutUntrackedOrigin], obj: Pointer[NoneType, MutUntrackedOrigin]
) abi("C"):
    _ = env
    var body = obj.unsafe_bitcast[Pin]()
    enif_release_resource(body[].obj)


def retained_dtor(
    env: Pointer[NoneType, MutUntrackedOrigin], obj: Pointer[NoneType, MutUntrackedOrigin]
) abi("C"):
    _ = env
    var body = obj.unsafe_bitcast[Retained]()
    enif_free_env(body[].env)


def open_type(
    env: Pointer[NoneType, MutUntrackedOrigin],
    name: StaticString,
    dtor: def(
        env: Pointer[NoneType, MutUntrackedOrigin], obj: Pointer[NoneType, MutUntrackedOrigin]
    ) abi("C") thin -> NoneType,
) -> Pointer[NoneType, MutUntrackedOrigin]:
    var tried = c_int(0)
    # The generated wrapper's dtor parameter is generic over an origin, and a
    # concrete thin function does not convert to that generic. Call the symbol
    # directly with the measured callback type.
    return external_call["enif_open_resource_type", Pointer[NoneType, MutUntrackedOrigin]](
        env, lit("Elixir.Mojoler.Own"), lit(name), dtor, c_int(1), Pointer(to=tried)
    )


def load(
    env: Pointer[NoneType, MutUntrackedOrigin],
    priv: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin],
    _info: c_ulong,
) abi("C") -> c_int:
    var box = must_alloc(c_size_t(size_of[Types]())).unsafe_bitcast[Types]()
    box[] = Types(
        open_type(env, "counter", counter_dtor),
        open_type(env, "blob", blob_dtor),
        open_type(env, "retained", retained_dtor),
        open_type(env, "pin", pin_dtor),
        enif_mutex_create(lit("mojoler-own")),
        c_long(0),
        c_long(1),
    )
    priv[] = box.unsafe_bitcast[NoneType]()
    return c_int(0)


def unload(
    env: Pointer[NoneType, MutUntrackedOrigin], priv: Pointer[NoneType, MutUntrackedOrigin]
) abi("C"):
    _ = env
    var box = priv.unsafe_bitcast[Types]()
    enif_mutex_destroy(box[].lock)
    must_free(priv)


def bad(env: Pointer[NoneType, MutUntrackedOrigin]) -> c_ulong:
    return enif_make_badarg(env)


def err(env: Pointer[NoneType, MutUntrackedOrigin], name: StaticString) -> c_ulong:
    var mem = must_alloc(c_size_t(16)).unsafe_bitcast[c_ulong]()
    mem[unsafe_offset=0] = enif_make_atom(env, lit("error"))
    mem[unsafe_offset=1] = enif_make_atom(env, lit(name))
    var out = enif_make_tuple_from_array(env, mem, c_uint(2))
    must_free(mem)
    return out


def ok_value(env: Pointer[NoneType, MutUntrackedOrigin], value: c_ulong) -> c_ulong:
    var mem = must_alloc(c_size_t(16)).unsafe_bitcast[c_ulong]()
    mem[unsafe_offset=0] = enif_make_atom(env, lit("ok"))
    mem[unsafe_offset=1] = value
    var out = enif_make_tuple_from_array(env, mem, c_uint(2))
    must_free(mem)
    return out


def get_obj(
    env: Pointer[NoneType, MutUntrackedOrigin],
    term: c_ulong,
    kind: Pointer[NoneType, MutUntrackedOrigin],
) -> Optional[Pointer[NoneType, MutUntrackedOrigin]]:
    var slot = must_alloc(c_size_t(8))
    var box = slot.unsafe_bitcast[Pointer[NoneType, MutUntrackedOrigin]]()
    var rc = enif_get_resource(env, term, kind, box)
    var obj = box[]
    must_free(slot)
    if rc == 0:
        return None
    return obj


def open_counter(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argv
    if argc != 0:
        return bad(env)
    var obj = enif_alloc_resource(types(env)[].counter, c_size_t(size_of[Counter]()))
    var body = obj.unsafe_bitcast[Counter]()
    var pid = ErlNifPid(c_ulong(0))
    _ = enif_self(env, Pointer(to=pid))
    body[] = Counter(c_long(0), c_long(0), pid^)
    var term = enif_make_resource(env, obj)
    enif_release_resource(obj)
    return term


def counter_add(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 2:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].counter)
    if not obj_opt:
        return bad(env)
    var n = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=1], Pointer(to=n)) == 0:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Counter]()
    var lock = types(env)[].lock
    enif_mutex_lock(lock)
    if body[].closed != 0:
        enif_mutex_unlock(lock)
        return err(env, "closed")
    body[].value = body[].value + n
    var value = body[].value
    enif_mutex_unlock(lock)
    return ok_value(env, enif_make_long(env, value))


def counter_close(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].counter)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Counter]()
    enif_mutex_lock(types(env)[].lock)
    body[].closed = c_long(1)
    enif_mutex_unlock(types(env)[].lock)
    return enif_make_atom(env, lit("ok"))


def open_blob(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var mem = must_alloc(c_size_t(size_of[ErlNifBinary]())).unsafe_bitcast[ErlNifBinary]()
    if enif_inspect_binary(env, argv[unsafe_offset=0], mem) == 0:
        must_free(mem)
        return err(env, "not_binary")
    var n = Int(mem[].size)
    var data = must_alloc(c_size_t(n if n > 0 else 1))
    var i = 0
    while i < n:
        data[unsafe_offset=i] = mem[].data[unsafe_offset=i]
        i += 1
    must_free(mem)
    var info = types(env)
    enif_mutex_lock(info[].lock)
    var token = info[].next_token
    info[].next_token = token + c_long(1)
    enif_mutex_unlock(info[].lock)
    var obj = enif_alloc_resource(info[].blob, c_size_t(size_of[Blob]()))
    var body = obj.unsafe_bitcast[Blob]()
    body[] = Blob(
        data,
        c_long(n),
        c_long(0),
        c_long(0),
        c_long(0),
        token,
    )
    var term = enif_make_resource(env, obj)
    enif_release_resource(obj)
    return term


def blob_borrow(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    enif_mutex_lock(types(env)[].lock)
    if body[].closed != 0 or body[].frozen != 0:
        enif_mutex_unlock(types(env)[].lock)
        return err(env, "not_mutable")
    body[].borrows = body[].borrows + c_long(1)
    var n = body[].size
    enif_mutex_unlock(types(env)[].lock)
    return ok_value(env, enif_make_long(env, n))


def blob_release(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    enif_mutex_lock(types(env)[].lock)
    if body[].borrows > 0:
        body[].borrows = body[].borrows - c_long(1)
    enif_mutex_unlock(types(env)[].lock)
    return enif_make_atom(env, lit("ok"))


def blob_freeze(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    enif_mutex_lock(types(env)[].lock)
    if body[].borrows != 0:
        enif_mutex_unlock(types(env)[].lock)
        return err(env, "borrowed")
    if body[].frozen != 0:
        enif_mutex_unlock(types(env)[].lock)
        return err(env, "frozen")
    body[].frozen = c_long(1)
    var data = body[].data
    var n = body[].size
    enif_mutex_unlock(types(env)[].lock)
    var bin = enif_make_resource_binary(env, obj_opt.value(), data.unsafe_bitcast[NoneType](), c_size_t(n))
    return ok_value(env, bin)


def blob_close(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    enif_mutex_lock(types(env)[].lock)
    body[].closed = c_long(1)
    enif_mutex_unlock(types(env)[].lock)
    return enif_make_atom(env, lit("ok"))


def blob_token(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    return ok_value(env, enif_make_long(env, body[].token))


def blob_poke(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 3:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var index = c_long(0)
    var byte = c_long(0)
    if enif_get_long(env, argv[unsafe_offset=1], Pointer(to=index)) == 0:
        return bad(env)
    if enif_get_long(env, argv[unsafe_offset=2], Pointer(to=byte)) == 0 or byte < 0 or byte > 255:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Blob]()
    enif_mutex_lock(types(env)[].lock)
    if body[].closed != 0 or body[].frozen != 0 or body[].borrows != 0:
        enif_mutex_unlock(types(env)[].lock)
        return err(env, "not_mutable")
    if index < 0 or index >= body[].size:
        enif_mutex_unlock(types(env)[].lock)
        return err(env, "bounds")
    body[].data[unsafe_offset=Int(index)] = UInt8(byte)
    enif_mutex_unlock(types(env)[].lock)
    return enif_make_atom(env, lit("ok"))


def blob_pin(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].blob)
    if not obj_opt:
        return bad(env)
    var obj = obj_opt.value()
    enif_keep_resource(obj)
    var pin = enif_alloc_resource(types(env)[].pin, c_size_t(size_of[Pin]()))
    var body = pin.unsafe_bitcast[Pin]()
    body[] = Pin(obj)
    var term = enif_make_resource(env, pin)
    enif_release_resource(pin)
    return term


def blob_dtors(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argv
    if argc != 0:
        return bad(env)
    return enif_make_long(env, types(env)[].blob_dtors)


def retain_binary(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var independent = enif_alloc_env()
    var copied = enif_make_copy(independent, argv[unsafe_offset=0])
    var obj = enif_alloc_resource(types(env)[].retained, c_size_t(size_of[Retained]()))
    var body = obj.unsafe_bitcast[Retained]()
    body[] = Retained(independent, copied)
    var term = enif_make_resource(env, obj)
    enif_release_resource(obj)
    return term


def read_retained(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    if argc != 1:
        return bad(env)
    var obj_opt = get_obj(env, argv[unsafe_offset=0], types(env)[].retained)
    if not obj_opt:
        return bad(env)
    var body = obj_opt.value().unsafe_bitcast[Retained]()
    return enif_make_copy(env, body[].term)


def upgrade(
    env: Pointer[NoneType, MutUntrackedOrigin],
    priv: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin],
    old: Pointer[Pointer[NoneType, MutUntrackedOrigin], MutUntrackedOrigin],
    info: c_ulong,
) abi("C") -> c_int:
    # OTP keeps the entry returned by nif_init. Upgrade is rejected so a second
    # image cannot assume it may free or replace that entry.
    _ = env
    _ = priv
    _ = old
    _ = info
    return c_int(1)


def put(
    funcs: Pointer[ErlNifFunc, MutUntrackedOrigin],
    i: Int,
    name: StaticString,
    arity: Int,
    f: def(
        env: Pointer[NoneType, MutUntrackedOrigin],
        argc: c_int,
        argv: Pointer[c_ulong, MutUntrackedOrigin],
    ) abi("C") thin -> c_ulong,
):
    funcs[unsafe_offset=i] = ErlNifFunc(lit(name), c_uint(arity), f, c_uint(0))


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(14)
    put(funcs, 0, "open_counter", 0, open_counter)
    put(funcs, 1, "counter_add", 2, counter_add)
    put(funcs, 2, "counter_close", 1, counter_close)
    put(funcs, 3, "open_blob", 1, open_blob)
    put(funcs, 4, "blob_borrow", 1, blob_borrow)
    put(funcs, 5, "blob_release", 1, blob_release)
    put(funcs, 6, "blob_freeze", 1, blob_freeze)
    put(funcs, 7, "blob_close", 1, blob_close)
    put(funcs, 8, "retain_binary", 1, retain_binary)
    put(funcs, 9, "read_retained", 1, read_retained)
    put(funcs, 10, "blob_token", 1, blob_token)
    put(funcs, 11, "blob_poke", 3, blob_poke)
    put(funcs, 12, "blob_pin", 1, blob_pin)
    put(funcs, 13, "blob_dtors", 0, blob_dtors)
    var load_fn = load
    var unload_fn = unload
    var upgrade_fn = upgrade
    var load_bits = Pointer(to=load_fn).unsafe_bitcast[Int]()[]
    var unload_bits = Pointer(to=unload_fn).unsafe_bitcast[Int]()[]
    var upgrade_bits = Pointer(to=upgrade_fn).unsafe_bitcast[Int]()[]
    return make_entry(
        lit("Elixir.Mojoler.Own"),
        funcs,
        c_int(14),
        callback_opt(load_bits),
        None,
        callback_opt(upgrade_bits),
        callback_opt(unload_bits),
    )
