# Guide

All available commands available for cargo-fuzz:

```sh
cargo fuzz --help
```

Run a target:


```sh
cargo fuzz run <fuzz target name>
```

## Cargo features

It is possible to fuzz crates with different configurations of Cargo features by using the command line options `--features`, `--no-default-features` and `--all-features`. Note that these options control the `fuzz_targets` crate; you will need to forward them to the crate being fuzzed by e.g. adding the following to `fuzz_targets/Cargo.toml`:

```toml
[features]
unsafe = ["project/unsafe"]
```

## `#[cfg(fuzzing)]`

Every crate instrumented for fuzzing -- the `fuzz_targets` crate, the project crate, and their entire dependency tree -- is compiled with the `--cfg fuzzing` rustc option. This makes it possible to disable code paths that prevent fuzzing from working, e.g. verification of cryptographic signatures, with a simple `#[cfg(not(fuzzing))]`, and without the need for an externally visible Cargo feature that must be maintained throughout every dependency.

## `#[cfg(fuzzing_repro)]`

When you run `cargo fuzz <fuzz target name> <crash file>`, every crate is compiled with the `--cfg fuzzing_repro` rustc option. This allows you to leave debugging statements in your fuzz targets behind a `#[cfg(fuzzing_repro)]`:

```rust
#[cfg(fuzzing_repro)]
eprintln!("Input data: {}", expensive_pretty_print(&data));
```

## libFuzzer configuration options

See all the libFuzzer options:

```sh
cargo fuzz run <fuzz target name> -- -help=1
```

For example, to generate only ASCII inputs, run:

```sh
cargo fuzz run <fuzz target name> -- -only_ascii=1
```
