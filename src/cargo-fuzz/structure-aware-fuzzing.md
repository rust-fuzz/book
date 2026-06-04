# Structure-Aware Fuzzing

Not every system under test wants to take a buffer of raw bytes as input; it
might want well-formed instances of some structured data. For example, here are
a few systems a fuzz target might be testing, and the data that it might want as
input:

| System Under Test          | Structured Input                                       |
|----------------------------|--------------------------------------------------------|
| A color-conversion library | An RGB color                                           |
| A compiler's type checker  | A syntactically valid source program                   |
| A compiler's optimizer     | A semantically valid source program                    |
| An allocator               | A sequence of `malloc`, `realloc`, and `free` commands |
| A `HashMap` implementation | A sequence of `insert`, `get`, and `remove` commands   |

Structure-aware fuzzing is when we produce fuzz inputs of a structured type,
rather than raw, pseudorandom bytes. This helps the fuzzer avoid uninteresting
"shallow" inputs that will be rejected early (e.g., syntactically invalid source
text when fuzzing a compiler) and focus on interesting inputs that go "deep"
into the system under test (e.g., programs that parse and type-check
successfully, and then exercise the compiler's mid-end optimizer and backend
code generator).

The `libfuzzer-sys` crate provides two methods for structure-aware fuzzing:

1. Structure-aware *mutation* via [the `fuzz_mutator!` macro][fuzz-mutator-macro]
2. Structure-aware *generation* via [the `Arbitrary` trait][arbitrary-trait]

The two methods are not mutually exclusive, but if you are implementing just
one, [an experiment has shown that `fuzz_mutator!`-based mutation provides
better coverage over time than `arbitrary`-based
generation](https://fitzgen.com/2026/06/01/structure-aware-fuzzing-experiment.html).

## Structure-Aware Mutation

[The `fuzz_mutator!` macro][fuzz-mutator-macro] allows us to define custom
mutators. The fuzzer will use this to create new inputs from existing inputs in
its corpus.

[The `mutatis` crate](https://docs.rs/mutatis) can often be helpful when writing
custom mutators.

This section includes two examples of mutation-based structure-aware fuzzing:

1. [Fuzzing Compressed Data](#example-compressed-data)

2. [Fuzzing A Data Structure Implementation](#example-fuzzing-a-data-structure)

### Example: Compressed Data

Consider a simple fuzz target that takes compressed data as input, decompresses
it, and then asserts that the decompressed data doesn't begin with "boom". It is
difficult for `libFuzzer` (or any other fuzzer) to crash this fuzz target
because nearly all mutations it makes will invalidate the compression
format. Therefore, we use a custom mutator that decompresses the raw input,
mutates the decompressed data, and then recompresses it. This allows `libFuzzer`
to quickly discover crashing inputs.

```rust,ignore
#![no_main]

use flate2::{read::GzDecoder, write::GzEncoder, Compression};
use libfuzzer_sys::{fuzz_mutator, fuzz_target};
use std::io::{Read, Write};

fuzz_target!(|data: &[u8]| {
    // Decompress the input data and crash if it starts with "boom".
    if let Some(data) = decompress(data) {
        if data.starts_with(b"boom") {
            panic!("uh oh!");
        }
    }
});

fuzz_mutator!(
    |data: &mut [u8], size: usize, max_size: usize, _seed: u32| {
        // Decompress the input data. If that fails, use a dummy value.
        let mut decompressed = decompress(&data[..size]).unwrap_or_else(|| b"hi".to_vec());

        // Mutate the decompressed data with `libFuzzer`'s default mutator. Make
        // the `decompressed` vec's extra capacity available for insertion
        // mutations via `resize`.
        let len = decompressed.len();
        let cap = decompressed.capacity();
        decompressed.resize(cap, 0);
        let new_decompressed_size = libfuzzer_sys::fuzzer_mutate(&mut decompressed, len, cap);

        // Recompress the mutated data.
        let compressed = compress(&decompressed[..new_decompressed_size]);

        // Copy the recompressed mutated data into `data` and return the new size.
        let new_size = std::cmp::min(max_size, compressed.len());
        data[..new_size].copy_from_slice(&compressed[..new_size]);
        new_size
    }
);

fn decompress(compressed_data: &[u8]) -> Option<Vec<u8>> {
    let mut decoder = GzDecoder::new(compressed_data);
    let mut decompressed = Vec::new();
    if decoder.read_to_end(&mut decompressed).is_ok() {
        Some(decompressed)
    } else {
        None
    }
}

fn compress(data: &[u8]) -> Vec<u8> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder
        .write_all(data)
        .expect("writing into a vec is infallible");
    encoder.finish().expect("writing into a vec is infallible")
}
```

### Example: Fuzzing a Data Structure

Imagine we are implementing persistent, immutable map data structure. We can
test the correctness of our map by comparing its results against a known-correct
map implementation (e.g. `std::collections::HashMap<K, V>`). This technique is
called *differential fuzzing*.

#### Add a `mutatis` dependency

We will use [the `mutatis` crate](https://docs.rs/mutatis), which defines
abstractions and combinators for writing custom mutators, so we need to add a
dependency:

```toml
# fuzz/Cargo.toml

[dependencies]
mutatis = { version = "0.5", features = ["derive"] }
```

#### Define a `MapMethod` type

This is an `enum` with a variant for each `PersistentImmutableMap<K, V>` method
we want to exercise. It should derive `mutatis::Mutate` and [`serde::{Serialize,
Deserialize}`](https://docs.rs/serde).

```rust,ignore
// fuzz/fuzz_targets/map_differential.rs

use mutatis::Mutate;
use serde::{Serialize, Deserialize};

/// A `PersistentImmutableMap<K, V>` method invocation command.
#[derive(Debug, Mutate, Serialize, Deserialize)]
enum MapMethod<K, V> {
    /// Insert a new entry into the map.
    Insert { key: K, value: V },
    /// Get this key's value from the map.
    Get { key: K },
    /// Remove this key's entry from the map.
    Remove { key: K },
}
```

#### Define a `fuzz_mutator!`

Use [`serde_json`](https://docs.rs/serde_json/) to deserialize our input type,
mutate it, and then reserialize it again. (We could also use `bincode` or
`postcard` or ... instead of `serde_json`.)

```rust,ignore
// fuzz/fuzz_targets/map_differential.rs

// ...

libfuzzer_sys::fuzz_mutator!(|data: &mut [u8], size: usize, max_size: usize, seed: u32| {
    // Try to deserialize a `Vec<MapMethod<String, u32>>`; fallback to an empty
    // vec on failure.
    let mut methods: Vec<MapMethods<String, u32>> = serde_json::from_slice(&data[..size])
        .ok()
        .unwrap_or_default();

    // Create a new mutation session.
    let mut session = mutatis::Session::new()
        // Use the given mutation seed.
        .seed(seed.into())
        // Only perform shrinking mutations if the max result size is less than
        // the input size.
        .shrink(max_size < size);

    // Mutate the methods.
    if session.mutate(&mut methods).is_ok() {
        // Serialize the methods back into JSON.
        let mut data = &mut data[..max_size];
        if serde_json::to_writer(&mut data, &methods).is_ok() {
            return data.len();
        }
    }

    // Fallback to default libfuzzer mutator
    fuzzer_mutate(data, size, max_size)
});
```

#### Define the fuzz target

The fuzz target deserializes the map methods, creates both an instance of our
data structure and the implementation we are comparing it against, and then
invokes the methods on both instances and asserts that they produce the same
results.

```rust,ignore
// fuzz/fuzz_targets/map_differential.rs

// ...

libfuzzer_sys::fuzz_target!(|data| {
    // Deserialize our map methods, or else ignore the input.
    let Ok(methods) = serde_json::from_slice::<Vec<MapMethods<String, u32>>>(data) else {
        return libfuzzer_sys::Corpus::Reject;
    };

    // Create an instance of our persistent, immutable map type, and an
    // instance of `std`'s hash map.
    let mut ours = PersistentImmutableMap::new();
    let mut theirs = std::collections::HashMap::new();

    // Interpret the `MapMethod` commands and assert that we get the same
    // results in our map as we get in the `std` map.
    for method in methods {
        match method {
            MapMethod::Insert { key, value } => {
                let their_old_entry = theirs.insert(key.clone(), value);
                let (new_ours, our_old_entry) = ours.insert(key, value);
                assert_eq!(their_old_entry, our_old_entry);
                ours = new_ours;
            }
            MapMethod::Get { key } => {
                let their_value = theirs.get(&key);
                let our_value = ours.get(&key);
                assert_eq!(their_value, our_value);
            }
            MapMethod::Remove { key } => {
                let their_old_entry = theirs.remove(&key);
                let (new_ours, our_old_entry) = ours.remove(&key);
                assert_eq!(their_old_entry, our_old_entry);
                ours = new_ours;
            }
        }
    }

    libfuzzer_sys::Corpus::Keep
});
```

## Structure-Aware Generation

The `fuzz_target!` macro allows us to define fuzz targets that take any kind of
input type, not just `&[u8]`, as long as the input type implements [the
`Arbitrary` trait][arbitrary-trait].

```rust,ignore
libfuzzer_sys::fuzz_target!(|input: AnyTypeThatImplementsArbitrary| {
    // Use `input` here...
})
```

The `arbitrary` crate implements `Arbitrary` for nearly all the types in `std`,
including collections like `Vec` and `HashMap` as well as things like `String`
and `PathBuf`.

For convenience, the `libfuzzer-sys` crate re-exports the `arbitrary` crate as
`libfuzzer_sys::arbitrary`. You can also enable `#[derive(Arbitrary)]` either by

* enabling the `arbitary` crate's `"derive"` feature, or
* (equivalently) enabling the `libfuzzer-sys` crate's `"arbitrary-derive"` feature.

[See the `arbitrary` crate's documentation for more details.](https://docs.rs/arbitrary)

This section includes two examples of generation-based structure-aware fuzzing:

1. [Fuzzing Color Conversions](#example-fuzzing-color-conversions)

2. [Fuzzing Allocation API Calls](#example-fuzzing-allocator-api-calls)

### Example: Fuzzing Color Conversions

Let's say we are working on a color conversion library that can turn RGB colors
into HSL and back again.

#### Enable Deriving `Arbitrary`

We are lazy, and don't want to implement `Arbitrary` by hand, so we want to
enable the `arbitrary` crate's `"derive"` cargo feature. This lets us get
automatic `Arbitrary` implementations with `#[derive(Arbitrary)]`.

Because the `Rgb` type we will be deriving `Arbitrary` for is in our main color
conversion crate, we add this to our main `Cargo.toml`.

```toml
# Cargo.toml

[dependencies]
arbitrary = { version = "1", optional = true, features = ["derive"] }
```

#### Derive `Arbitrary` for our `Rgb` Type

In our main crate, when the `"arbitrary"` cargo feature is enabled, we derive
the `Arbitrary` trait:

```rust,ignore
// src/lib.rs

#[derive(Clone, Debug)]
#[cfg_attr(feature = "arbitrary", derive(arbitrary::Arbitrary))]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}
```

#### Enable the Main Project's `"arbitrary"` Cargo Feature for the Fuzz Targets

Because we made `arbitrary` an optional dependency in our main color conversion
crate, we need to enable that feature for our fuzz targets to use it.

```toml
# fuzz/Cargo.toml

[dependencies]
my_color_conversion_library = { path = "..", features = ["arbitrary"] }
```

#### Add the Fuzz Target

We need to add a new fuzz target to our project:

```sh
$ cargo fuzz add rgb_to_hsl_and_back
```

#### Implement the Fuzz Target

Finally, we can implement our fuzz target that takes arbitrary RGB colors,
converts them to HSL, and then converts them back to RGB and asserts that we get
the same color as the original! Because we implement `Arbitrary` for our `Rgb`
type, our fuzz target can take instances of `Rgb` directly:

```rust,ignore
// fuzz/fuzz_targets/rgb_to_hsl_and_back.rs

libfuzzer_sys::fuzz_target!(|color: Rgb| {
    let hsl = color.to_hsl();
    let rgb = hsl.to_rgb();

    // This should be true for all RGB -> HSL -> RGB conversions!
    assert_eq!(color, rgb);
});
```

### Example: Fuzzing Allocator API Calls

Imagine, for example, that we are fuzzing our own `malloc` and `free`
implementation. We want to make a sequence of valid allocation and deallocation
API calls. Additionally, we want that sequence to be guided by the fuzzer, so it
can use its insight into code coverage to maximize the amount of code we
exercise during fuzzing.

#### Add the Fuzz Target

First, we add a new fuzz target to our project:

```sh
$ cargo fuzz add fuzz_malloc_free
```

#### Enable Deriving `Arbitrary`

Like the color conversion example above, we don't want to write our `Arbitrary`
implementation by hand, we want to derive it.

```toml
# fuzz/Cargo.toml

[dependencies]
libfuzzer-sys = { version = "0.4.0", features = ["arbitrary-derive"] }
```

#### Define an `AllocatorMethod` Type and Derive `Arbitrary`

Next, we define an `enum` that represents either a `malloc`, a `realloc`, or a
`free`:

```rust,ignore
// fuzz_targets/fuzz_malloc_free.rs

use libfuzzer_sys::arbitrary::Arbitrary;

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

#### Write a Fuzz Target That Takes a Sequence of `AllocatorMethod`s

Finally, we write a fuzz target that takes a vector of `AllocatorMethod`s and
interprets them by making the corresponding `malloc`, `realloc`, and `free`
calls. This works because `Vec<T>` implements `Arbitrary` when `T` implements
`Arbitrary`.

```rust,ignore
// fuzz/fuzz_targets/fuzz_malloc_free.rs

libfuzzer_sys::fuzz_target!(|methods: Vec<AllocatorMethod>| {
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
[fuzz-mutator-macro]: https://docs.rs/libfuzzer-sys/latest/libfuzzer_sys/macro.fuzz_mutator.html
