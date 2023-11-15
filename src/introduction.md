# Introduction

[Fuzz testing][] is a software testing technique used to find security and stability issues by providing pseudo-random data as input to the software.

[Rust][] is a high performance, safe, general purpose programming language.

This book demonstrates how to perform fuzz testing for software written in Rust.

There are three tools for fuzzing Rust code: **[afl.rs]** and **[cargo-fuzz]** which are documented in this book; and **[honggfuzz-rs]** which is documented on its homepage.  

The source of this book is available on GitHub at <https://github.com/rust-fuzz/book>.

[Fuzz testing]: https://en.wikipedia.org/wiki/Fuzz_testing
[Rust]: https://www.rust-lang.org/
[cargo-fuzz]: cargo-fuzz.html
[afl.rs]: afl.html
[honggfuzz-rs]: https://crates.io/crates/honggfuzz
