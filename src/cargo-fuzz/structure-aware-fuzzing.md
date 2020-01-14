# Structure-Aware Fuzzing

Not every fuzz target wants to take a buffer of raw bytes as input. We might
want to only feed it well-formed instances of some structured data. Luckily, the
`libfuzzer` crate enables us to define fuzz targets that take any kind of type,
as long as it implements [the `Arbitrary` trait][arbitrary-trait].

## Example

Imagine, for example, that we are fuzzing our own `malloc` and `free`
implementation. We want to make a sequence of valid allocation and deallocation
API calls. Additionally, we want that sequence to be guided by the fuzzer, so it
can use its insight into code coverage to maximize the amount of code we
exercise during fuzzing.

### Add the Fuzz Target

First, we initialize a new fuzz target for our project:

```sh
$ cargo fuzz add fuzz_malloc_free
```

### Enable Deriving `Arbitrary`

We are lazy, and don't want to implement `Arbitrary` by hand, so we want to
enable the `"arbitrary-derive"` cargo feature. This lets us get automatic
`Arbitrary` implementations with `#[derive(Arbitrary)]`:

```toml
# fuzz/Cargo.toml

[dependencies]
libfuzzer = { version = "0.2.0", features = ["arbitrary-derive"] }
```

### Define an `AllocatorMethod` Type and Derive `Arbitrary`

Next, we define an `enum` that represents either a `malloc`, a `realloc`, or a
`free`:

```rust
// fuzz_targets/fuzz_malloc_free.rs

use libfuzzer::arbitrary::Arbitrary;

#[derive(Arbitrary, Debug)]
enum AllocatorMethod {
    Malloc {
        // The size of allocation to make.
        size: usize,
    },
    Free {
        // Free the index^th allocation we've made.
        index: usize
    },
    Realloc {
        // We will realloc the index^th allocation we've made.
        index: usize,
        // The new size of the allocation.
        new_size: usize,
    },
}
```

### Write a Fuzz Target That Takes a Sequence of `AllocatorMethod`s

Finally, we write a fuzz target that takes a vector of `AllocatorMethod`s and
interprets them by making the corresponding `malloc`, `realloc`, and `free`
calls.

```rust
// fuzz_targets/fuzz_malloc_free.rs

libfuzzer::fuzz_target!(|methods: Vec<AllocatorMethod>| {
    let mut allocs = vec![];

    // Interpret the fuzzer-provided methods and make the
    // corresponding allocator API calls.
    for method in methods {
        match method {
            AllocatorMethod::Malloc { size } => {
                let ptr = my_allocator::malloc(size);
                allocs.push(ptr);
            }
            AllocatorMethod::Free { index } => {
                match allocs.get(index) {
                    Some(ptr) if !ptr.is_null() => {
                        my_allocator::free(ptr);
                        allocs[index] = std::ptr::null();
                    }
                    _ => {}
                }
            }
            AllocatorMethod::Realloc { index, size } => {
                match allocs.get(index) {
                    Some(ptr) if !ptr.is_null() => {
                        let new_ptr = my_allocator::realloc(ptr, size);
                        allocs[index] = new_ptr;
                    }
                    _ => {}
                }
            }
        }
    }

    // Free any remaining allocations.
    for ptr in allocs {
        if !ptr.is_null() => {
            my_allocator::free(ptr);
        }
    }
});
```

[arbitrary-trait]: https://docs.rs/arbitrary/*/arbitrary/trait.Arbitrary.html
