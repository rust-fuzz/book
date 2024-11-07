# Fuzzing Windows DLLs

On Windows systems, shared libraries are called [**Dynamic Link
Libraries**](https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/dynamic-link-library)
(**DLLs**). Code can be compiled into a `.dll` file, which is then loaded in at
run-time by other executables on the system.

You might find yourself wanting to fuzz a Windows DLL. Like any other piece of
software, a shared library would benefit from undergoing fuzzing. Currently,
fuzzing a Windows DLL is possible, but *slightly* trickier. Read on!

## How do I Build and Fuzz a DLL?

Follow these steps to build your DLL for fuzzing and build your fuzzing targets
to invoke it.

### Set up your Fuzzing `Cargo.toml`

Add your DLL's Cargo project to your fuzzing `Cargo.toml` as an optional
dependency:

```toml
[dependencies]
# ...
your_dll = { path = "..", optional = true }
# ...
```

Add a feature to your `Cargo.toml` that requires your DLL as a dependency. We
want the DLL to be built *only* when this feature is enabled:

```toml
[features]
# ...
build_your_dll = [
    "dep:your_dll"
]
# ...
```

Finally, create a fuzzing target in your `Cargo.toml` that requires this
feature. This will be a "dummy" fuzzing target whose sole purpose is to build
your DLL. It won't actually do any fuzzing; it's merely a way to have
cargo-fuzz build your DLL with AddressSanitizer (and other) instrumentation.

```toml
[[bin]]
name = "build_your_dll"
path = "fuzz_targets/build_your_dll.rs"
required-features = ["build_your_dll"]
test = false
doc = false
bench = false
```

### Create the "Dummy" Fuzzing Target

Next, you need to create the source code for this "dummy" fuzzing target
(`fuzz_targets/build_your_dll.rs`). At its simplest, all you need to do is
create a simple `main` function:

```rust
pub fn main()
{
    println!("DLL build complete!");
}
```

This "dummy" target will have its main function executed *after* the DLL build
has completed, so if you'd like, you can add extra code here to perform any
post-build installation or setup. (For example, perhaps you need to copy the
built DLL to somewhere else on the system, in order for the fuzzing targets to
find it.)

### Create your Fuzzing Targets

After that, it's cargo-fuzz business as usual: create your fuzzing targets in
`Cargo.toml`, and have them load and invoke your DLL:

```toml
[[bin]]
name = "fuzz_your_dll_1"
path = "fuzz_targets/fuzz_your_dll_1.rs"
test = false
doc = false
bench = false
```

### Build the DLL and Run

To build the DLL, then run a fuzzing target, there are two separate commands
you need to invoke:

```powershell
# Build the DLL with your "dummy" target
cargo fuzz run --features=build_your_dll --no-include-main-msvc --strip-dead-code build_your_dll
```

(See the ["Technical Details"](#Technical-Details) for more information on why
these options are needed.)

```powershell
# Run your fuzzing target, now that your DLL is built
cargo fuzz run fuzz_your_dll_1
```

## Technical Details

<details>
<summary>
(Why do we have to fuzz DLLs this way? Click here to see some details.)
</summary>

Code that is fuzzed through cargo-fuzz must be compiled with extra
instrumentation inserted. The binary that is produced behaves normally, but
executes additional code that cargo-fuzz (which uses
[LibFuzzer](https://llvm.org/docs/LibFuzzer.html) under the hood) can use to
recieve feedback about how the target program behaved when given inputs from the
fuzzer. In this way, a fuzzing "feedback loop" is established, and the fuzzer
can slowly generate more "interesting" inputs that create new behavior in the
target program.

In our case, the target program is a Windows DLL. Because it's a DLL
(shared library), it must be built and instrumented as a completely separate
binary (a `.dll` file) from any fuzzing target executable (`.exe`) we've
developed to test it. Your fuzzing target programs
(`..../fuzz/fuzz_target/*.rs`) are calling functions from this DLL, but the
actual loading of those functions into the same process will occur at run-time.

So, there are two steps that need to be done when building (hence the two
separate `cargo fuzz run ...` commands listed above):

1. Build the DLL and install it.
2. Build the fuzzing targets.

### MSVC and LibFuzzer's `main` Function

On Windows, Rust uses the [MSVC compiler and
linker](https://learn.microsoft.com/en-us/cpp/build/reference/compiling-a-c-cpp-program)
to build. The cargo-fuzz fuzzing targets do not implement a `main` function;
instead, they use LibFuzzer's built-in `main` function. (This function is what
actually starts up the fuzzer. The fuzzer then invokes the `fuzz_target!()`
macro function defined in each fuzzing target.) The MSVC linker does not
seem to recognize the LibFuzzer `main` function, and thus cannot build the
fuzzing targets without a little help.

To fix the problem, cargo-fuzz code adds
the `/include:main` linker argument to the build arguments passed to `cargo
build` when it detects systems that are building with MSVC. This arguments
forces the inclusion of an external `main` symbol in the executables produced by
MSVC. (See more on the `/include` argument
[here](https://learn.microsoft.com/en-us/cpp/build/reference/include-force-symbol-references).)
This allows the fuzzing targets to build.

### Adding `/include:main` breaks DLL Linking

But hang on a second! DLLs by nature are shared libraries, and thus should not
have any references to a `main` function. It's the job of the executable that
loads a DLL into worry about `main`. So, if we attempt to build a DLL using
`cargo fuzz build`, it'll add the `/include:main`, and we'll get a linker error:

```txt
LINK : error LNK2001: unresolved external symbol main
C:/..../my_shared_library.dll : fatal error LNK1120: 1 unresolved externals
```

To avoid this, we use the `--no-include-main-msvc` argument, which allows us to
control whether or not `/include:main` is added to the MSVC linker arguments.

### But removing `/include:main` breaks Fuzzing Target Linking

However... we need `/include:main` to build the fuzzing target executables. This
puts us at a bit of an impasse:

* If we add `/include:main`, the fuzzing targets will build, but the DLL will
  not.
* If we remove `/include:main`, the DLL will build, but the fuzzing targets will
  not.

### Solution: Two Separate Builds

To solve this, we need to invoke `cargo fuzz ...` twice: once to build the DLL
(*without* `/include:main`), and another time to build the fuzzing targets
(*with* `/include:main`). In order to build the DLL using cargo-fuzz (which we
want to do, because it builds using all the relevant LLVM coverage and
AddressSanitizer compiler options), we implement a small "dummy" fuzzing target
that provides its own `main` function.

This "dummy" target does not implement a `fuzz_target!()` macro function (and
thus, no actual fuzzing occurs), but it acts as a vehicle for us to build the
Windows DLL for fuzzing. Plus, you can add any extra code to this "dummy" target
to help install your newly-built DLL in the correct location on your Windows
system.

### Why Use `--strip-dead-code`?

By default, cargo-fuzz invokes rustc with the `-Clink-dead-code` argument.
This, as described
[here](https://doc.rust-lang.org/rustc/codegen-options/index.html#link-dead-code),
controls whether or not the linker is instructed to keep dead code. "Dead code"
refers to functions/symbols that are provided by some dependency (such as a
DLL) but aren't ever referenced/used by the program that's importing code from
the dependency. This can be useful in some cases, but harmful in others.

In the case of the certain DLLs, it may be harmful. By building with
`-Clink-dead-code`, references to unused functions/symbols within various
Windows DLLs your target DLL is dependent on would be included in the resulting
binary when you build it with cargo-fuzz.

For example: in [windows-rs](https://github.com/microsoft/windows-rs), the
Cryptography sub-crate (`windows::Win32::Security::Cryptography`) includes
symbols from `infocardapi.dll`). This DLL appears to no longer be supported, or
even installed on Windows. If `-Clink-dead-code` were to cause these symbols to
be included in your DLL, loading will fail at run-time when, inevitably, those
symbol references can't be found, since `infocardapi.dll` is nowhere to be
found on the system. (Your fuzzing target program will fail with
`STATUS_DLL_NOT_FOUND`.)

This issue can be fixed by adding `--strip-dead-code` to your cargo-fuzz
command, which removes the usage of `-Clink-dead-code` when building.

</details>

