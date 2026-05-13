# Writing Oracles that Access Data

Rust requires that a reference should point to a valid value, as defined in [The Rust Reference](https://doc.rust-lang.org/reference/behavior-considered-undefined.html#r-undefined.validity.reference-box):

> A reference or `Box<T>` must be aligned and non-null, it cannot be dangling, and it must point to a valid value.

As a result, a high-quality harness should validate **every reference** obtained from the target library.

It's very flexible to design APIs with callbacks in Rust, while it's not easy to write good fuzzing harnesses for those.

```rust,ignore
pub fn api_with_callback(user_data: &[u8], callback: impl Fn(&[u32])) {
    let dangling_data_ptr: *mut u32 = process_user_data(user_data);
    let data_len: usize = HARDCODED_VALUE;
    let data = unsafe { std::slice::from_raw_parts(dangling_data_ptr, data_len) };
    callback(data);
}
```

In the above example, creating slice from dangling pointer is definitely a UB. However, current fuzzing solutions are often equipped only with address sanitizer, which will detect violations only if an invalid memory is **accessed**. As a result, the creation of such a slice will not be caught by the address sanitizer, and the effectiveness depends on the quality of fuzzing harnesses.

```rust,ignore
// Bad harness
fuzz_target!(|data: &[u8]| {
    api_with_callback(data, |lib_data| {});
});

// Good harness
fuzz_target!(|data: &[u8]| {
    api_with_callback(data, |lib_data| {
        lib_data.iter().for_each(|byte_ref| {
            core::hint::black_box(*byte_ref);
        });
    });
});
```

In the good harness above, each byte of `lib_data` is accessed (and the [`black_box`](https://doc.rust-lang.org/std/hint/fn.black_box.html) is used to avoid the access being optimized out), and any invalid memory accesses will be caught by address sanitizers, leading to effective bug detection.

As described above, the reference data can be obtained either from the API's return value, or in the parameters of callbacks. As long as a reference is obtained from the target library, such a reference should be checked in the fuzzing harness to catch unsoundness. Beyond manuanlly writing checking patterns, crates like [touched](https://crates.io/crates/touched) provide convenient utilities for this purpose.
