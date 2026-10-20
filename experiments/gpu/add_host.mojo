# Standalone GPU check. One thread adds 20 and 22 on device and the host
# prints the copied-back value. This file is not a NIF.

from std.sys import has_accelerator

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

def main() raises:
    comptime if not has_accelerator():
        print("No compatible GPU found")
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

        var lhs_tensor = TileTensor(lhs_device, layout)
        var rhs_tensor = TileTensor(rhs_device, layout)
        var result_tensor = TileTensor(result_device, layout)
        ctx.enqueue_function[vector_addition](
            lhs_tensor,
            rhs_tensor,
            result_tensor,
            grid_dim=1,
            block_dim=1,
        )
        var result_host = ctx.enqueue_create_host_buffer[float_dtype](vector_size)
        ctx.enqueue_copy(dst_buf=result_host, src_buf=result_device)
        ctx.synchronize()
        print("gpu_add", result_host[0])
