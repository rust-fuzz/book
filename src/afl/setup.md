# Setup

## Requirements

### Tools

* C compiler (e.g. gcc or clang)
* make

### Platform

afl.rs works on x86-64 Linux. It is possible for afl.rs to work on x86-64 macOS, but support is blocked on [this rustc bug](https://github.com/rust-lang/rust/issues/22915) ([tracking issue](https://github.com/rust-fuzz/afl.rs/issues/118)).

## Installing

```sh
cargo install afl
```

## Upgrading

```sh
cargo install --force afl
```
