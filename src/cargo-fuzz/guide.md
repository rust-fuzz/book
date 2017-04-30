# Guide

All available commands available for cargo-fuzz:

```sh
cargo fuzz --help
```

Run a target:


```sh
cargo fuzz run <fuzz target name>
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
