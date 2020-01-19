# Structure-Aware Fuzzing

Not every fuzz target wants to take a buffer of raw bytes as input. We might
want to only feed it well-formed instances of some structured data. Luckily, the
`libfuzzer-sys` crate enables us to define fuzz targets that take any kind of type,
as long as it implements [the `Arbitrary` trait][arbitrary-trait].

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

This section concludes with two examples of structure-aware fuzzing:

1. [Example 1: Fuzzing Color Conversions](#example-1-fuzzing-color-conversions)

2. [Example 2: Fuzzing Allocation API Calls](#example-2-fuzzing-allocator-api-calls)

## Example 1: Fuzzing Color Conversions

Let's say we are working on a color conversion library that can turn RGB colors
into HSL and back again.

### Enable Deriving `Arbitrary`

We are lazy, and don't want to implement `Arbitrary` by hand, so we want to
enable the `arbitrary` crate's `"derive"` cargo feature. This lets us get
automatic `Arbitrary` implementations with `#[derive(Arbitrary)]`.

Because the `Rgb` type we will be deriving `Arbitrary` for is in our main color
conversion crate, we add this to our main `Cargo.toml`.

```toml
# Cargo.toml

[dependencies]
arbitrary = { version = "0.3.0", optional = true, features = ["derive"] }
```

### Derive `Arbitrary` for our `Rgb` Type

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

### Enable the Main Project's `"arbitrary"` Cargo Feature for the Fuzz Targets

Because we made `arbitrary` an optional dependency in our main color conversion
crate, we need to enable that feature for our fuzz targets to use it.

```toml
# fuzz/Cargo.toml

[dependencies]
my_color_conversion_library = { path = "..", features = ["arbitrary"] }
```

### Add the Fuzz Target

We need to add a new fuzz target to our project:

```sh
$ cargo fuzz add rgb_to_hsl_and_back
```

### Implement the Fuzz Target

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

## Example 2: Fuzzing Allocator API Calls

Imagine, for example, that we are fuzzing our own `malloc` and `free`
implementation. We want to make a sequence of valid allocation and deallocation
API calls. Additionally, we want that sequence to be guided by the fuzzer, so it
can use its insight into code coverage to maximize the amount of code we
exercise during fuzzing.

### Add the Fuzz Target

First, we add a new fuzz target to our project:

```sh
$ cargo fuzz add fuzz_malloc_free
```

### Enable Deriving `Arbitrary`

Like the color conversion example above, we don't want to write our `Arbitrary`
implementation by hand, we want to derive it.

```toml
# fuzz/Cargo.toml

[dependencies]
libfuzzer-sys = { version = "0.2.0", features = ["arbitrary-derive"] }
```

### Define an `AllocatorMethod` Type and Derive `Arbitrary`

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

### Write a Fuzz Target That Takes a Sequence of `AllocatorMethod`s

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
