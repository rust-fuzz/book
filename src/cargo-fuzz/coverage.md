# Code Coverage

Visualizing code coverage helps you understand which code paths are being fuzzed
and &mdash; more importantly &mdash; which aren't. To help the fuzzer exercise
new code paths, you can look at what it is failing to reach and then either add
new seed inputs to the corpus, or tweak the fuzz target. This chapter describes
how to generate coverage reports for your fuzz target and its current corpus.

## Prerequisites

First, install the LLVM-coverage tools as described in the [Unstable
book][install-cov-tools].

We recommend using at least LLVM 11 and a recent nightly version of the Rust
toolchain. This code was tested with `1.51.0-nightly (2021-02-10)`.

You must also have `cargo fuzz` version `0.10.0` or newer to use the `cargo fuzz
coverage` subcommand.

## Generate Code-Coverage Data

After you fuzzed your program, use the `coverage` command to generate precise
[source-based code coverage][source-based-code-cov] information:

```shell
$ cargo fuzz coverage <target> [corpus dirs] [-- <args>]
```

This command

- compiles your project using the `-Zinstrument-coverage` Rust compiler flag,

- runs the program _without fuzzing_ on the provided corpus (if no corpus
  directory is provided it uses `fuzz/corpus/<target>` by default),

- for each input file in the corpus, generates raw coverage data in the
  `fuzz/coverage/<target>/raw` subdirectory, and

- merges the raw files into a `coverage.profdata` file located in the
  `fuzz/coverage/<target>` subdirectory.

Afterwards, you can use the generated `coverage.profdata` file to generate
coverage reports and visualize code-coverage information as described in the
[Unstable book][create-reports].

## Example

Suppose we have a `my_compiler` fuzz target for which we want to visualize code
coverage.

1. Run the fuzzer on the `my_compiler` target:

   ```shell
   $ cargo fuzz run my_compiler
   ```

2. Produce code-coverage information:

   ```shell
   $ cargo fuzz coverage my_compiler
   ```

2. Visualize the coverage data in HTML:

   ```shell
   $ cargo cov -- show target/.../my_compiler \
       --format=html \
       -instr-profile=fuzz/coverage/my_compiler/coverage.profdata \
       > index.html
   ```

   There are many visualization and coverage-report options available (see `llvm-cov show --help`).

[install-cov-tools]: https://doc.rust-lang.org/beta/unstable-book/compiler-flags/source-based-code-coverage.html#installing-llvm-coverage-tools
[source-based-code-cov]: https://blog.rust-lang.org/inside-rust/2020/11/12/source-based-code-coverage.html
[create-reports]: https://doc.rust-lang.org/beta/unstable-book/compiler-flags/source-based-code-coverage.html#creating-coverage-reports
