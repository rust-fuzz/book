# Creating Unit Tests from Fuzz Crashes

Some of the crashes may be useful to convert into unit tests as part of the codebase.
This enables them to live on as regression tests and makes them easy to run automatically.

The vulnerable code in the tutorial crashes. The codebase also includes various unit tests, 
but none that test the vulnerable behavior.

## Approach to creating a unit test that exercises the vulnerability

The code implemented in the fuzz target can provide the basis of the code in the unit test; and
the data bytes the payload. Some crashes might not need any data, e.g. if the reproduction
file doesn't contain any data.

Here's a straight-forward example based on the vulnerable code. The data bytes were obtained 
from the minified cargo fuzz test case. (They could simply be taken from the test that causes
the crash.)

```
#![no_main]
#[macro_use] extern crate libfuzzer_sys;
extern crate url;

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = url::Url::parse(s);
    }
});
```

The above code is modified as follows by hard-coding the data bytes as a new unit test in: 
`src/tests.rs` of the codebase in the tutorial. These are shown when the crash occurs and can
be obtained (on macOS and \*nix) using the `od` command, for instance:
```
od -t dC fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98
0000000  102  105  108  101   58  101
0000006
```

```
#[test]
fn from_fuzz_crash() {
    // fuzz payload data bytes go here
    let data = [102, 105, 108, 101, 58, 101];

    if let Ok(s) = std::str::from_utf8(&data) {
        let _ = Url::parse(s);
    }
}
```

The unit tests can be run with:
```
cargo test
```

The newly added test *should* fail until the vulnerability is fixed. For the tutorial, 
check out `HEAD` and re-add this new unit test to confirm it now passes. Note: the 
latest codebase includes many more tests and the previous file (`./src/tests.rs`) no longer
exists. The new test can be added to `url/tests/unit.rs` instead.

## More detail
Here are extracts from the results of running `cargo fuzz` on the vulnerable code in the 
tutorial, and then minifying the test case.

```
cargo fuzz run fuzz_target_1 -- -max_total_time=200
```

```
<<--cut-->>
NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal
MS: 5 ChangeByte-EraseBytes-CopyPart-CopyPart-CMP- DE: "file"-; base unit: 5ecdf68dbfd208e40c2c5d3867194232458f0ff0
0x66,0x69,0x6c,0x65,0x3a,0x69,0x0,0x65,
file:i\000e
artifact_prefix='/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/'; Test unit written to /home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/crash-420742a84803bc64cbeb97952d220909c7f91d98
Base64: ZmlsZTppAGU=

────────────────────────────────────────────────────────────────────────────────

Failing input:

	fuzz/artifacts/fuzz_target_1/crash-420742a84803bc64cbeb97952d220909c7f91d98

Output of `std::fmt::Debug`:

	[102, 105, 108, 101, 58, 105, 0, 101]

Reproduce with:

	cargo fuzz run fuzz_target_1 fuzz/artifacts/fuzz_target_1/crash-420742a84803bc64cbeb97952d220909c7f91d98

Minimize test case with:

	cargo fuzz tmin fuzz_target_1 fuzz/artifacts/fuzz_target_1/crash-420742a84803bc64cbeb97952d220909c7f91d98

────────────────────────────────────────────────────────────────────────────────

Error: Fuzz target exited with exit status: 77
```

```
cargo fuzz tmin fuzz_target_1 fuzz/artifacts/fuzz_target_1/crash-420742a84803bc64cbeb97952d220909c7f91d98
```

```
<<--cut-->>

NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal
MS: 1 EraseBytes-; base unit: 0000000000000000000000000000000000000000
0x66,0x69,0x6c,0x65,0x3a,0x65,
file:e
artifact_prefix='/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/'; Test unit written to /home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98
Base64: ZmlsZTpl
*********************************
CRASH_MIN: minimizing crash input: '/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98' (6 bytes)
CRASH_MIN: executing: fuzz/target/x86_64-unknown-linux-gnu/release/fuzz_target_1 -artifact_prefix=/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/ -runs=255 /home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98 2>&1
CRASH_MIN: '/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98' (6 bytes) caused a crash. Will try to minimize it further
CRASH_MIN: executing: fuzz/target/x86_64-unknown-linux-gnu/release/fuzz_target_1 -artifact_prefix=/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/ -runs=255 /home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98 -minimize_crash_internal_step=1 -exact_artifact_path=/home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-6d35450fed027ca1da631e61e9b5cc3d8780dea3 2>&1
INFO: Running with entropic power schedule (0xFF, 100).
INFO: Seed: 3517758038
INFO: Loaded 1 modules   (2888 inline 8-bit counters): 2888 [0x59b475604470, 0x59b475604fb8), 
INFO: Loaded 1 PC tables (2888 PCs): 2888 [0x59b475604fb8,0x59b475610438), 
INFO: Starting MinimizeCrashInputInternalStep: 6
INFO: -max_len is not provided; libFuzzer will not generate inputs larger than 6 bytes
INFO: Done MinimizeCrashInputInternalStep, no crashes found
CRASH_MIN: failed to minimize beyond /home/username/sandbox/rust-url/fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98 (6 bytes), exiting

────────────────────────────────────────────────────────────────────────────────

Minimized artifact:

	fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98

Output of `std::fmt::Debug`:

	[102, 105, 108, 101, 58, 101]

Reproduce with:

	cargo fuzz run fuzz_target_1 fuzz/artifacts/fuzz_target_1/minimized-from-420742a84803bc64cbeb97952d220909c7f91d98

```
