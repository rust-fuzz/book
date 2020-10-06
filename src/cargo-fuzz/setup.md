# Setup

## Requirements

libFuzzer needs LLVM sanitizer support, so this only works on x86-64 Linux and x86-64 macOS for now. This also needs a nightly compiler since it uses some unstable command-line flags. You'll also need a C++ compiler with C++11 support.

## Installing

```sh
cargo install cargo-fuzz
```

## Upgrading

```sh
cargo install --force cargo-fuzz
```
