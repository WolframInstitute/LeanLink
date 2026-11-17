---
Template: Symbol
Name: InstallLeanToolchain
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/InstallLeanToolchain
Keywords: [Lean, toolchain, elan, install, runtime]
SeeAlso: [InstallMathlib, LeanImport, LeanEvaluate, LeanBuild]
RelatedGuides: [LeanLink]
RelatedTutorials: [LeanLinkIntro]
---

## Usage

<code>[InstallLeanToolchain]()[]</code> installs the Lean toolchain LeanLink is built against and gives <code>[File]()[*dir*]</code> for the toolchain.

## Details & Options

- LeanLink's native library loads the Lean runtime of the toolchain it is built against, `leanprover/lean4:v4.35.0`, and [LeanEvaluate]() and [LeanBuild]() run its `lean` and `lake`. [InstallLeanToolchain]() installs that toolchain with [elan](https://github.com/leanprover/elan), Lean's toolchain manager, as `elan toolchain install leanprover/lean4:v4.35.0` does in a shell.
- It installs elan when there is no working elan, from an installer pinned by URL and SHA-256. elan goes into `ELAN_HOME` when that is set, else `~/.elan`, with no change to the shell profile, the `PATH` of the kernel, or elan's default toolchain.
- On an installed toolchain it starts no process and downloads nothing.
- When LeanLink's native library could not be loaded earlier in the session because the toolchain was missing, it is loaded again on its next use.
- [InstallMathlib]() installs the toolchain the same way before Mathlib.
- A failed installation gives a [Failure]() whose tag names the step: `"ElanInstallFailed"` or `"ToolchainInstallFailed"`, or `"DownloadFailed"` or `"DownloadChecksum"` for the elan installer.
- The following options are accepted:

| Option | Default | Description |
|---|---|---|
| `"ProgressFunction"` | `(Null &)` | a function called with the stage, such as `"Downloading..."`, and the fraction done, or `None` |
| `"CancellationFunction"` | `(False &)` | a function that gives `True` to stop the installation |

- The cancellation function is called between steps and while a download or a command runs. When it gives `True`, the command is stopped and [InstallLeanToolchain]() gives `Failure["InstallCancelled", ...]`. An abort stops the command too.

## Basic Examples

Install the toolchain, or find it installed:

```wl
FileNameTake[InstallLeanToolchain[]]
```

<!-- => "leanprover--lean4---v4.35.0" -->

## Options

### ProgressFunction

Print each stage as the installation reaches it:

```wl
#| eval: false
InstallLeanToolchain["ProgressFunction" -> Function[{stage, fraction}, Print[stage]]]
```

### CancellationFunction

A cancellation function that gives `True` stops the installation before it starts:

```wl
InstallLeanToolchain["CancellationFunction" -> (True &)]
```

<!-- => Failure["InstallCancelled", ...] -->
