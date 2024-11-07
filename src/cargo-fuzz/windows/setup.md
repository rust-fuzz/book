# Windows Setup

It's possible to use cargo-fuzz to fuzz Rust code on Windows. This guide aims
to shed some light on how you can get cargo-fuzz up and running on a Windows
system.

## 1. Install Visual Studio

Make sure you have Visual Studio installed; there are a number of features
that need to be installed alongside it in order for the fuzzing code to build.
Follow [this
guide](https://learn.microsoft.com/en-us/visualstudio/install/install-visual-studio)
to install the "Visual Studio Installer". Use it to make sure you have the
following individual components installed:

* MSVC v143 - VS 2022 C++ x64/x86 build tools
    * (This was the latest at the time of writing - you may install a newer
      version if you're reading this at a later point in time!)
* C++ AddressSanitizer

## 2. Set up PowerShell

Certain directories must be on the PowerShell system `$env:PATH` in order for
builds to succeed and for certain cargo-fuzz commands to work.  The `Developer
PowerShell for VS 2022` and/or `x64 Native Tools Command Prompt for VS 2022`
may have these directories already on the path. If they don't, or you are using
a different PowerShell, make sure these directories are added to the shell's
`$env:PATH`:

* `C:\Program Files\Microsoft Visual Studio\Community\VC\Tools\MSVC\<VERSION_NUMBER>\bin\Hostx86\64`
    * Where `<VERSION_NUMBER>` is the MSVC version you have installed.
* (Optional) `C:\Program Files (x86)\Windows Kits\10\Debuggers\x64`
    * Add this if you want to use the [Windows
      Debugger](https://learn.microsoft.com/en-us/windows-hardware/drivers/debuggercmds/windbg-overview)
      to debug your fuzzing targets.

These paths may very slightly on your machine, but the main idea is that your
shell needs to be able to find the MSVC-based AddressSanitizer DLL as well as
the other MSVC-related binaries.

