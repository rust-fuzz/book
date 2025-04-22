# Fuzzing in CI

It can be helpful, as a smoke test, to build and run your fuzz targets for a
small amount of time in CI.

If your CI provider of choice is not listed here, feel free to send a PR adding
it.

## GitHub Workflows

```yaml
name: Smoke-Test Fuzz Targets

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  fuzz:
    runs-on: ubuntu-latest

    env:
      # The version of `cargo-fuzz` to install and use.
      CARGO_FUZZ_VERSION: 0.12.0

      # The number of seconds to run the fuzz target. 300 seconds = 5 minutes.
      FUZZ_TIME: 300

    strategy:
      matrix:
        include:
          # TODO: List your fuzz targets here.
          - fuzz_target: my_first_fuzz_target
          - fuzz_target: my_second_fuzz_target
          # etc...

    steps:
    - uses: actions/checkout@v4

    # Install the nightly Rust channel.
    - run: rustup toolchain install nightly
    - run: rustup default nightly

    # Install and cache `cargo-fuzz`.
    - uses: actions/cache@v4
      with:
        path: ${{ runner.tool_cache }}/cargo-fuzz
        key: cargo-fuzz-bin-${{ env.CARGO_FUZZ_VERSION }}
    - run: echo "${{ runner.tool_cache }}/cargo-fuzz/bin" >> $GITHUB_PATH
    - run: cargo install --root "${{ runner.tool_cache }}/cargo-fuzz" --version ${{ env.CARGO_FUZZ_VERSION }} cargo-fuzz --locked

    # Build and then run the fuzz target.
    - run: cargo fuzz build ${{ matrix.fuzz_target }}
    - run: cargo fuzz run ${{ matrix.fuzz_target }} -- -max_total_time=${{ env.FUZZ_TIME }}

    # Upload fuzzing artifacts on failure for post-mortem debugging.
    - uses: actions/upload-artifact@v4
      if: failure()
      with:
        name: fuzzing-artifacts-${{ matrix.fuzz_target }}-${{ github.sha }}
        path: fuzz/artifacts
```
