# Separate NIF from priv/native/libpoc.so. The callback runs the same
# one-element GPU add as add_host.mojo and returns the copied-back integer.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong, external_call
from std.runtime import initialize_runtime
from std.sys import has_accelerator, size_of

from max.gpu.host import DeviceContext
from max.gpu import block_dim, block_idx, thread_idx
from layout import TileTensor, row_major

comptime float_dtype = DType.float32
comptime vector_size = 1
comptime layout = row_major[vector_size]()

def vector_addition(
    lhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    rhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    out_tensor: TileTensor[float_dtype, type_of(layout), MutAnyOrigin],
):
    var tid = block_idx.x * block_dim.x + thread_idx.x
    if tid < vector_size:
        out_tensor[tid] = lhs_tensor[tid] + rhs_tensor[tid]

def gpu_twenty_plus_twenty_two() raises -> Int:
    comptime if not has_accelerator():
        raise Error("No compatible GPU found")
    else:
        var ctx = DeviceContext()
        var lhs_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        var rhs_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        ctx.synchronize()
        lhs_host[0] = Float32(20.0)
        rhs_host[0] = Float32(22.0)
        var lhs_device = ctx.enqueue_create_buffer[float_dtype](vector_size)
        var rhs_device = ctx.enqueue_create_buffer[float_dtype](vector_size)
        var result_device = ctx.enqueue_create_buffer[float_dtype](vector_size)
        ctx.enqueue_copy(dst_buf=lhs_device, src_buf=lhs_host)
        ctx.enqueue_copy(dst_buf=rhs_device, src_buf=rhs_host)
        ctx.enqueue_function[vector_addition](
            TileTensor(lhs_device, layout),
            TileTensor(rhs_device, layout),
            TileTensor(result_device, layout),
            grid_dim=1,
            block_dim=1,
        )
        var result_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        ctx.enqueue_copy(dst_buf=result_host, src_buf=result_device)
        ctx.synchronize()
        return Int(result_host[0])

@fieldwise_init
struct NifFunc(RegisterPassable):
    var name: Pointer[c_char, ImmStaticOrigin]
    var arity: c_uint
    var fptr: def(
        env: Pointer[NoneType, MutUntrackedOrigin],
        argc: c_int,
        argv: Pointer[c_ulong, MutUntrackedOrigin],
    ) abi("C") thin -> c_ulong
    var flags: c_uint

@fieldwise_init
struct NifEntry(RegisterPassable):
    var major: c_int
    var minor: c_int
    var name: Pointer[c_char, ImmStaticOrigin]
    var num_of_funcs: c_int
    var funcs: Pointer[NifFunc, MutUntrackedOrigin]
    var load: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var reload: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var upgrade: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var unload: Optional[Pointer[NoneType, MutUntrackedOrigin]]
    var vm_variant: Pointer[c_char, ImmStaticOrigin]
    var options: c_uint
    var sizeof_resource_init: c_size_t
    var min_erts: Pointer[c_char, ImmStaticOrigin]

def gpu_sum(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argc
    _ = argv
    initialize_runtime()
    try:
        var value = gpu_twenty_plus_twenty_two()
        return external_call["enif_make_long", c_ulong](env, c_long(value))
    except:
        return external_call["enif_make_badarg", c_ulong](env)

def must_alloc(nbytes: c_size_t) -> Pointer[UInt8, MutUntrackedOrigin]:
    var mem = external_call["calloc", Optional[Pointer[UInt8, MutUntrackedOrigin]]](
        c_size_t(1), nbytes
    )
    if not mem:
        external_call["abort", NoneType]()
    return mem.value()

@export("nif_init")
def nif_init() abi("C") -> Pointer[NifEntry, MutUntrackedOrigin]:
    var funcs = must_alloc(c_size_t(size_of[NifFunc]())).unsafe_bitcast[NifFunc]()
    funcs[] = NifFunc("sum".as_c_string_span().ptr(), c_uint(0), gpu_sum, c_uint(0))
    var entry = must_alloc(c_size_t(size_of[NifEntry]())).unsafe_bitcast[NifEntry]()
    entry[] = NifEntry(
        c_int(2),
        c_int(17),
        "Elixir.Mojoler.GPUProbe".as_c_string_span().ptr(),
        c_int(1),
        funcs,
        None,
        None,
        None,
        None,
        "beam.vanilla".as_c_string_span().ptr(),
        c_uint(1),
        c_size_t(40),
        "erts-14.0".as_c_string_span().ptr(),
    )
    return entry
