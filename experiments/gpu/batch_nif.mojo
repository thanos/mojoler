# Opt-in batched Apple GPU add. experiments/gpu/gpu_nif.mojo is unchanged
# and remains the one-call historical proof. This file is a separate library.
# A machine without a device returns {:error, :no_device}. It does not add on
# the CPU and then report success.

from std.ffi import c_char, c_int, c_long, c_size_t, c_uint, c_ulong
from std.runtime import initialize_runtime
from std.sys import has_accelerator

from max.gpu.host import DeviceContext
from max.gpu import block_dim, block_idx, thread_idx
from layout import TileTensor, row_major

from mojoler.abi.otp_nif import (
    ErlNifEntry,
    ErlNifFunc,
    abi_dirty_cpu,
    enif_make_atom,
    enif_make_long,
    enif_make_tuple_from_array,
)
from mojoler.abi.prim import alloc_funcs, make_entry, must_alloc, must_free

comptime float_dtype = DType.float32
comptime vector_size = 4
comptime layout = row_major[vector_size]()


def vector_addition(
    lhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    rhs_tensor: TileTensor[float_dtype, type_of(layout), ImmutAnyOrigin],
    out_tensor: TileTensor[float_dtype, type_of(layout), MutAnyOrigin],
):
    var tid = block_idx.x * block_dim.x + thread_idx.x
    if tid < vector_size:
        out_tensor[tid] = lhs_tensor[tid] + rhs_tensor[tid]


def batch_sum() raises -> Int:
    comptime if not has_accelerator():
        raise Error("No compatible GPU found")
    else:
        var ctx = DeviceContext()
        var lhs_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        var rhs_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        ctx.synchronize()
        lhs_host[0] = Float32(1.0)
        lhs_host[1] = Float32(2.0)
        lhs_host[2] = Float32(3.0)
        lhs_host[3] = Float32(4.0)
        rhs_host[0] = Float32(10.0)
        rhs_host[1] = Float32(20.0)
        rhs_host[2] = Float32(30.0)
        rhs_host[3] = Float32(40.0)
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
            block_dim=vector_size,
        )
        var result_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        ctx.enqueue_copy(dst_buf=result_host, src_buf=result_device)
        ctx.synchronize()
        var total = 0
        var i = 0
        while i < vector_size:
            total += Int(result_host[i])
            i += 1
        return total


def lit(text: StaticString) -> Pointer[c_char, ImmStaticOrigin]:
    return text.as_c_string_span().ptr()


def no_device(env: Pointer[NoneType, MutUntrackedOrigin]) -> c_ulong:
    var mem = must_alloc(c_size_t(16)).unsafe_bitcast[c_ulong]()
    mem[unsafe_offset=0] = enif_make_atom(env, lit("error"))
    mem[unsafe_offset=1] = enif_make_atom(env, lit("no_device"))
    var out = enif_make_tuple_from_array(env, mem, c_uint(2))
    must_free(mem)
    return out


def batch(
    env: Pointer[NoneType, MutUntrackedOrigin],
    argc: c_int,
    argv: Pointer[c_ulong, MutUntrackedOrigin],
) abi("C") -> c_ulong:
    _ = argc
    _ = argv
    initialize_runtime()
    try:
        var value = batch_sum()
        return enif_make_long(env, c_long(value))
    except:
        return no_device(env)


@export("nif_init")
def nif_init() abi("C") -> Pointer[ErlNifEntry, MutUntrackedOrigin]:
    var funcs = alloc_funcs(1)
    funcs[] = ErlNifFunc(lit("batch"), c_uint(0), batch, abi_dirty_cpu())
    return make_entry(
        lit("Elixir.Mojoler.GPUBatch"),
        funcs,
        c_int(1),
        None,
        None,
        None,
        None,
    )
