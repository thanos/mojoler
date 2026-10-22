# Unit 10 — Resources and finalizers

## Objectives

Watch one destructor run once, and watch a pin delay it.

## Why

RSS is a bad oracle for "freed exactly once". A counter incremented in the destructor is an oracle.

## Model

```text
enif_alloc_resource   native refcount = 1
enif_make_resource    BEAM term holds a ref
enif_release_resource drop the constructor's ref
GC of the last term   destructor
enif_keep_resource    an extra ref that a pin owns
```

## Theory

`open_counter` stores the caller pid and sends `:counter_destroyed` from the destructor. The test drops the term, forces GC, and asserts one message. A second message does not arrive.

`blob_pin` keeps the blob and returns another resource. The pin's destructor releases that keep. The test garbage-collects the holder while the pin term is live and checks `blob_dtors` did not move, then drops the pin and waits until it does.

Close is a flag, not a free. `counter_close` twice returns `:ok` both times. `counter_add` after close is `{:error, :closed}`.

The upgrade callback returns 1 so a reload cannot assume it may free the entry. No test actually upgraded a library. Do not read the callback as measured upgrade behavior.

Concurrent `counter_add` of 1, twenty times, ends at 20. The mutex is `enif_mutex_*` created in `load` and destroyed in `unload`.

## Lab

```sh
mix test test/own_test.exs
```

## Expected

The destructor test, the pin test, and the concurrent test pass. GC timing is polled, not assumed to be instant.

## Code

`native/own.mojo` `counter_dtor` and `pin_dtor`. The type pointer lives in the private box from `enif_priv_data`.

## Failure

A destructor that calls back into the dead process's environment, or that `enif_free`s `calloc` memory, will take the VM with it. The counter destructor only sends on the dtor env, which OTP allows for `enif_send`.

## Exercise

What does double-close return, and what does add-after-close return?

## Answer

`:ok`, then `{:error, :closed}`. The second close does not send a second destructor message. The destructor waits for the last resource ref.
