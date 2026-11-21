---
Template: Symbol
Name: InstallMathlib
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/InstallMathlib
Keywords: [Lean, Mathlib, install, lake, cache, toolchain, Git, curl]
SeeAlso: [MathlibInstallation, InstallLeanToolchain, LeanImport, LeanBuild]
RelatedGuides: [LeanLink]
RelatedTutorials: [ComputingWithMathlib, ExploringMathlib]
---

## Usage

<code>[InstallMathlib]()[]</code> installs the Mathlib release built with LeanLink's Lean toolchain and gives <code>[File]()[*dir*]</code> for the Lake project that requires it.

<code>[InstallMathlib]()["Directory" -> *dir*]</code> installs it in *dir*.

## Details & Options

- [LeanImport]() loads compiled modules built with the toolchain LeanLink's native library is built against, `leanprover/lean4:v4.36.0`. [InstallMathlib]() installs the Mathlib release of that toolchain, the tag `v4.36.0`, at commit `56a005855ea17e0b0958f73ec801ae140b0a1679`.
- It installs the toolchain first, as [InstallLeanToolchain]() does.
- The installation is a Lake project that requires Mathlib, which Lake keeps in its `.lake/packages/mathlib`. The project's `lake-manifest.json` comes with LeanLink and pins Mathlib and each package Mathlib uses by commit. Mathlib itself comes from a shallow Git clone of the tag, which Lake uses as it is. `lake exe cache get` fetches the other packages and Mathlib's build cache, every module compiled, several gigabytes, and `lake build Mathlib` then checks it.
- Git and curl must be installed: Lake fetches the packages with Git, and Mathlib's cache tool downloads with curl, which must support HTTPS. Where one is missing, [InstallMathlib]() gives a `"GitUnavailable"` or `"CurlUnavailable"` [Failure]() that says how to install it.
- The default directory is <code>[$UserBaseDirectory]()/ApplicationData/LeanLink/Mathlib/v4.36.0</code>. A *dir* that holds other files, or a Lake project of its own, gives a [Failure]() and is left as it is.
- [InstallMathlib]() never runs `lake update`, which would move the packages past the pinned commits. It writes `leanlink-mathlib.json`, its record of the installation, and `leanlink-mathlib.log`, the output of its commands, into the project.
- Run again, [InstallMathlib]() resumes where it stopped, keeping what it fetched. On a ready installation it starts no process, downloads nothing and gives the directory; it needs neither Git nor curl then.
- Loading LeanLink and calling [MathlibInstallation]() install nothing.
- A failed installation gives a [Failure]() whose tag names the step: `"MathlibInstallFailed"` for a failed command, with its `"Command"`, its `"Result"` and the `"Log"` file.
- After an installation, a message names Mathlib that [InstallMathlib]() installed for other toolchains, which this version of LeanLink cannot load; with `"RemoveOtherVersions" -> True` it removes them instead.
- The following options are accepted:

| Option | Default | Description |
|---|---|---|
| `"Directory"` | `Automatic` | the directory of the Lake project |
| `"ProgressFunction"` | `(Null &)` | a function called with each stage, such as `"Downloading..."` |
| `"CancellationFunction"` | `(False &)` | a function that gives `True` to stop the installation |
| `"RemoveOtherVersions"` | `False` | whether to remove Mathlib installed for other toolchains |

- The cancellation function is called at each stage and before each command. When it gives `True`, [InstallMathlib]() stops and gives `Failure["InstallCancelled", ...]`. An abort stops a command that is running, with the processes it started.

## Basic Examples

Install Mathlib, once:

```wl
#| eval: false
InstallMathlib[]
```

Check the installation:

```wl
MathlibInstallation[]["Status"]
```

<!-- => "Ready" -->

## Options

### Directory

Install into a directory of your own:

```wl
#| eval: false
InstallMathlib["Directory" -> FileNameJoin[{$HomeDirectory, "LeanMathlib"}]]
```

### ProgressFunction

Print each stage as the installation reaches it:

```wl
#| eval: false
InstallMathlib["ProgressFunction" -> Print]
```

### CancellationFunction

A cancellation function that gives `True` stops the installation before it starts:

```wl
InstallMathlib["CancellationFunction" -> (True &)]
```

<!-- => Failure["InstallCancelled", ...] -->

### RemoveOtherVersions

After LeanLink moves to a new toolchain, install Mathlib for it and remove the Mathlib of the old one:

```wl
#| eval: false
InstallMathlib["RemoveOtherVersions" -> True]
```
