# Setup

## Requirements

libFuzzer needs LLVM sanitizer support; this works on x86-64 Linux, x86-64 macOS and Apple-Silicon (aarch64) macOS, and Windows (thanks to the [MSVC AddressSanitizer][msvc-asan]). Requires a C++ compiler with C++11 support. Rust provides multiple compilers. This project requires the nightly compiler since it uses the `-Z` compiler flag to provide address sanitization. Assuming you used [rustup][rustup] to install Rust, you can check your default compiler with:

```shell
$ rustup default
stable-x86_64-unknown-linux-gnu (default) # Not the compiler we want.
```

To change to the nightly compiler:

```shell
$ rustup install nightly
$ rustup default nightly
nightly-x86_64-unknown-linux-gnu (default) # The correct compiler.
```

## Installing

```sh
cargo install cargo-fuzz
```

## Upgrading

```sh
cargo install --force cargo-fuzz
```

[rustup]: https://github.com/rust-lang/rustup
[msvc-asan]: https://learn.microsoft.com/en-us/cpp/sanitizers/asan
