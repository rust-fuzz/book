# Fuzzing with cargo-fuzz

[cargo-fuzz][] is the recommended tool for fuzz testing Rust code.

cargo-fuzz is itself not a fuzzer, but a tool to invoke a fuzzer. Currently, the only fuzzer it supports is [libFuzzer][] (through the [libfuzzer-sys][] crate), but it could be extended to [support other fuzzers in the future][extending].

[cargo-fuzz]: https://github.com/rust-fuzz/cargo-fuzz
[extending]: https://github.com/rust-fuzz/cargo-fuzz/issues/1
[libfuzzer-sys]: https://github.com/rust-fuzz/libfuzzer
[libFuzzer]: http://llvm.org/docs/LibFuzzer.html
