# Value ownership and value lifecycles

Mojo gives every value one owner. The owner’s lifetime is the value’s lifetime. When that lifetime ends, Mojo destroys the value and runs its deinitializer. A NIF sits on top of a second set of rules: the BEAM owns terms, and a pointer into a BEAM binary is valid only for the call that received it.

The Mojo half of this page follows the 1.1.0 manual:

- [Intro to value ownership](https://mojolang.org/docs/manual/values/)
- [Value semantics](https://mojolang.org/docs/manual/values/value-semantics/)
- [Ownership](https://mojolang.org/docs/manual/values/ownership/)
- [Lifetimes, origins, and references](https://mojolang.org/docs/manual/values/lifetimes/)
- [Value lifecycles](https://mojolang.org/docs/manual/lifecycle/)
- [Creating values](https://mojolang.org/docs/manual/lifecycle/life/)
- [Automatic destruction](https://mojolang.org/docs/manual/lifecycle/death/)
- [Ownership cheat sheet](https://mojolang.org/docs/reference/cheat-sheets/ownership/)

## One owner

A variable owns its value. A struct owns its fields. A reference lets another function read or write that value without becoming the owner.

Three rules, from the [ownership page](https://mojolang.org/docs/manual/values/ownership/):

- Every value has only one owner at a time.
- When the owner’s lifetime ends, Mojo destroys the value.
- An outstanding reference extends the owner’s lifetime until the reference is done.

Small values such as `Int` and `Float64` are value-semantic. Assigning one copies it. Changing the copy leaves the original alone:

```mojo
def main():
    var x = 1
    var y = x
    y += 1
    print("x:", x)
    print("y:", y)
```

`x` stays 1 and `y` becomes 2. A `String` or a `List` is still owned by one variable, but the bytes live on the heap. The owner’s deinitializer frees that buffer.

## How a function receives a value

The word in front of an argument is the convention. With no word, the argument is a read-only borrow: the function sees the caller’s value and cannot change it.

| Convention | What the function has |
| --- | --- |
| *(none)* | Read-only reference. The caller keeps the owner. |
| `mut` | Writable reference. Changes are visible to the caller. |
| `var` | Ownership of a value. That value may be a transfer, a copy, or a brand-new value. |
| `ref` | A reference whose mutability follows the value it points at. |
| `out` | Uninitialized on entry. The function must initialize it before returning. Used for `self` in `__init__` and for named results. |
| `deinit` | Initialized on entry, uninitialized on return. Used by `__deinit__` and by functions that finish another value’s life. |

A mutable update of the caller’s integer:

```mojo
def add(mut x: Int, y: Int):
    x += y

def main():
    var a = 1
    var b = 2
    add(a, b)
    print(a)  # 3
```

A read-only walk of a list does not copy the list:

```mojo
def print_list(list: List[Int]):
    print(list.__str__())
```

`mut` is exclusive. A function that takes `mut s` and another reference to the same `String` is rejected, because both names would alias one mutable value. `Int` is exempt: it is passed in a register, so two integer arguments are two copies.

## Transfer

`var` means the callee owns the argument it received. The caller chooses how that happens:

- `message^` transfers. `message` is uninitialized afterward. Using it is a compile error.
- `message` with no sigil copies, when the type is `Copyable`.
- A fresh value, such as a string literal or a function result, has no owner yet, so ownership goes straight to the callee.

```mojo
def take_text(var text: String):
    text += "!"
    print(text)

def main():
    var message = "Hello"
    take_text(message^)
```

After `message^`, nothing remains to print. The [Get started](https://mojolang.org/docs/manual/get-started/) tutorial uses the same sigil to hand a `Grid` back to the caller and to swap the two generation buffers inside `evolve`:

```mojo
return grid^
```

```mojo
var tmp = self.cells^
self.cells = self.next_cells^
self.next_cells = tmp^
```

Each of those lines has one owner for the list. The `^` is what makes the swap safe: the compiler will not let you read a buffer you have already given away.

## Where a value’s life starts

A value begins in an initializer. `__init__` takes `out self`, which is uninitialized on entry, and must write every field before it returns. `@fieldwise_init` generates that initializer when each field is just an argument.

```mojo
struct MyStruct:
    var field1: Int
    var field2: String

    def __init__(out self, field1: Int, field2: String):
        self.field1 = field1
        self.field2 = field2
```

Copy and transfer are initializers too:

```mojo
var the_copy = value.copy()
var the_move = value^
```

`Copyable` provides `copy()` and `__init__(out self, *, copy: Self)`. `ImplicitlyCopyable` lets the compiler insert a copy. Prefer an explicit `copy()` when the copy allocates. A move-only type such as `OwnedPointer` transfers and does not copy. An immovable type stays at one address for its whole life.

The [quickstart](https://mojolang.org/docs/manual/quickstart/) average is a value that lives for one call. The list is borrowed, the total is a local `Float64`, and the returned number is a new value:

```mojo
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    var total = 0.0
    for temp in temps:
        total += temp
    return total / Float64(len(temps))
```

`temps` is read-only. `total` is destroyed when the function returns. The `Float64` result is a new owner in the caller.

## Where a value’s life ends

Mojo destroys a value at its last use, not at the closing brace. That is the as-soon-as-possible rule on the [automatic destruction](https://mojolang.org/docs/manual/lifecycle/death/) page. The destructor is `__deinit__(deinit self)`. Fields are still valid inside it. When it returns, the value is dead. Mojo generates a destructor for a struct whose fields have one. Call it yourself only when you are wrapping destruction; ordinary code lets the compiler insert the call.

Inside `__deinit__`, taking a field with `^` is allowed, because this is the last use:

```mojo
def __deinit__(deinit self):
    var name = self.name^
```

To keep a value alive until a later line, mark that line as the last use:

```mojo
var t = "xyz"
print(t)
_ = t
```

The discard is the tool for a lock that must cover the next few statements, or for a pointer whose origin was erased and would otherwise dangle. The compiler does not guess that an external system still needs the address.

## Across the NIF

Elixir values and Mojo values are different owners. A NIF callback receives an `ERL_NIF_TERM`. That word is a handle. The BEAM owns the term. Mojo may borrow it for the duration of the callback and must not store the pointer.

| What you call | Who owns the bytes afterward |
| --- | --- |
| `Mojoler.Term.borrow_stable/1` | The BEAM. The function compares two inspect pointers and returns a size and `1`. The pointer is freed before the return. |
| `Mojoler.Term.copy_binary/1` | A new BEAM binary. The third element is how many bytes were copied. |
| `Mojoler.Term.fill_output/1` | A binary the VM allocated for the return. Mojo writes into it and hands it back. |
| `Mojoler.Own.open_blob/1` | A resource. The native buffer is a calloc copy. Elixir holds a handle, never the address. |
| `Mojoler.Own.blob_freeze/1` | The BEAM, as a resource binary. A later poke is `{:error, :not_mutable}`. Closing the resource does not invalidate that binary. |
| `Mojoler.Own.retain_binary/1` | A private `enif` environment. The copy is readable after the process that created it has exited. |

```elixir
{:ok, <<1, 2, 3>>, 3} = Mojoler.Term.copy_binary(<<1, 2, 3>>)
{:ok, 3, 1} = Mojoler.Term.borrow_stable(<<1, 2, 3>>)

blob = Mojoler.Own.open_blob(<<1, 2, 3>>)
{:ok, 3} = Mojoler.Own.blob_borrow(blob)
:ok = Mojoler.Own.blob_release(blob)
{:ok, <<1, 2, 3>>} = Mojoler.Own.blob_freeze(blob)
```

`borrow_stable` is the default argument convention: look, do not take. `copy_binary` is an explicit copy. `blob_freeze` is the transfer: the resource buffer becomes the binary’s storage, and the blob is no longer a writable owner.

Two `calloc` blocks for the NIF entry and its function table stay until the OS process exits. OTP keeps the entry, and a second `load_nif` is rejected. `Mojoler.Own` frees its private type box in `unload` with libc `free`. That pairing is the library’s deinitializer. The entry itself has no earlier last-use.

Unit 11 walks the binary cases with the tests: [Binary ownership](tutorial/11-binary-ownership.md). Chapter 07 is the earlier memory account: [Memory and lifetime](07-memory-and-lifetime.md).
