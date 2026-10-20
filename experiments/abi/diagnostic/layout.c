/*
 * DIAGNOSTIC ONLY.
 * Prints offsetof/sizeof for the installed OTP NIF structs.
 * scripts/build-native.sh must never link this file into libpoc.so.
 */
#include <stdio.h>
#include <stddef.h>
#include "erl_nif.h"

#define SHOW(T, F) \
    printf("  %-40s offset=%-3zu size=%zu\n", #T "." #F, offsetof(T, F), sizeof(((T *)0)->F))

int main(void) {
    printf("pointer=%zu int=%zu unsigned=%zu long=%zu size_t=%zu\n",
           sizeof(void *), sizeof(int), sizeof(unsigned), sizeof(long), sizeof(size_t));
    printf("ERL_NIF_MAJOR=%d ERL_NIF_MINOR=%d\n", ERL_NIF_MAJOR_VERSION, ERL_NIF_MINOR_VERSION);
    printf("ERL_NIF_TERM size=%zu\n", sizeof(ERL_NIF_TERM));
    printf("ErlNifFunc sizeof=%zu align=%zu\n", sizeof(ErlNifFunc), _Alignof(ErlNifFunc));
    SHOW(ErlNifFunc, name);
    SHOW(ErlNifFunc, arity);
    SHOW(ErlNifFunc, fptr);
    SHOW(ErlNifFunc, flags);
    printf("ErlNifEntry sizeof=%zu align=%zu\n", sizeof(ErlNifEntry), _Alignof(ErlNifEntry));
    SHOW(ErlNifEntry, major);
    SHOW(ErlNifEntry, minor);
    SHOW(ErlNifEntry, name);
    SHOW(ErlNifEntry, num_of_funcs);
    SHOW(ErlNifEntry, funcs);
    SHOW(ErlNifEntry, load);
    SHOW(ErlNifEntry, reload);
    SHOW(ErlNifEntry, upgrade);
    SHOW(ErlNifEntry, unload);
    SHOW(ErlNifEntry, vm_variant);
    SHOW(ErlNifEntry, options);
    SHOW(ErlNifEntry, sizeof_ErlNifResourceTypeInit);
    SHOW(ErlNifEntry, min_erts);
    printf("ErlNifResourceTypeInit sizeof=%zu align=%zu\n",
           sizeof(ErlNifResourceTypeInit), _Alignof(ErlNifResourceTypeInit));
    SHOW(ErlNifResourceTypeInit, dtor);
    SHOW(ErlNifResourceTypeInit, stop);
    SHOW(ErlNifResourceTypeInit, down);
    SHOW(ErlNifResourceTypeInit, members);
    SHOW(ErlNifResourceTypeInit, dyncall);
    printf("vm_variant=\"%s\" min_erts=\"%s\"\n", ERL_NIF_VM_VARIANT, ERL_NIF_MIN_ERTS_VERSION);
    printf("dirty cpu=%d io=%d\n", ERL_NIF_DIRTY_JOB_CPU_BOUND, ERL_NIF_DIRTY_JOB_IO_BOUND);
    return 0;
}
