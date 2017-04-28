# Introduction

[Fuzz testing][] is a software testing technique used to find security and stability issues by providing pseudo-random data as input to the software.

[Rust][] is a high performance, safe, general purpose programming language.

This book will demonstrate how to perform fuzz testing for software written in Rust. The two main sections cover two different approaches. The recommended approach is with [cargo-fuzz](cargo-fuzz.html) as its setup and workflow are much easier than with [afl.rs](afl.rs.html).

[Fuzz testing]: https://en.wikipedia.org/wiki/Fuzz_testing
[Rust]: https://www.rust-lang.org/
