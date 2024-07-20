# Installing from source

First, clone afl.rs:

```sh
git clone https://github.com/rust-fuzz/afl.rs
cd afl.rs
```

Next, checkout afl.rs's submodule ([AFL++]). Note that `--recursive` is not required.

```sh
git submodule update --init
```

Finally, install `cargo-afl`:

```sh
cargo install --path cargo-afl
```

## Troubleshooting

If `cargo-afl` is panicking, consider installing with `--debug` and running `cargo-afl` with `RUST_BACKTRACE=1`, e.g.:

```sh
cargo install --path cargo-afl --debug
...
RUST_BACKTRACE=1 cargo afl ...
```

Adding `--debug` to the `cargo install` command causes `cargo-afl` to produce more elaborate backtraces.

[AFL++]: https://github.com/AFLplusplus/AFLplusplus