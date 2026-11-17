---
Template: Symbol
Name: MathlibInstallation
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/MathlibInstallation
Keywords: [Lean, Mathlib, installation, status, directory, toolchain, revision]
SeeAlso: [InstallMathlib, LeanImport]
RelatedGuides: [LeanLink]
RelatedTutorials: [ComputingWithMathlib]
---

## Usage

<code>[MathlibInstallation]()[]</code> gives the status, directory and pinned versions of the Mathlib installation.

<code>[MathlibInstallation]()["Directory" -> *dir*]</code> checks the installation in *dir*.

## Details & Options

- The result is an [Association]() with the keys `"Status"`, `"Directory"`, `"Toolchain"`, `"Revision"`, `"DocumentationURL"`, `"Executables"` and `"OtherVersions"`.
- `"Status"` is `"Ready"`, `"Needs setup"` or `"Not installed"`. A ready installation has the project files and the record [InstallMathlib]() writes, Mathlib checked out at the pinned commit with no change to a tracked file and built, and LeanLink's native library loads the toolchain's runtime.
- `"Directory"` is the Lake project to give [LeanImport]() as `"ProjectDir"`. `"Toolchain"` is the pinned Lean toolchain and `"Revision"` the Mathlib commit.
- `"DocumentationURL"` is Mathlib's documentation site, which follows Mathlib's development and can describe a newer release.
- `"Executables"` gives the programs an installation runs, under the keys `"Elan"`, `"Lake"`, `"Git"` and `"Curl"`: a path, or [Missing]() where none is found. `"Lake"` is the toolchain's own.
- `"OtherVersions"` lists the directories of Mathlib that [InstallMathlib]() installed for other toolchains, which this version of LeanLink cannot load and <code>[InstallMathlib]()["RemoveOtherVersions" -> True]</code> removes.
- [MathlibInstallation]() downloads and installs nothing.
- The following option is accepted:

| Option | Default | Description |
|---|---|---|
| `"Directory"` | `Automatic` | the directory of the Lake project to check |

## Basic Examples

Whether Mathlib is installed and ready:

```wl
MathlibInstallation[]["Status"]
```

<!-- => "Ready" -->

The pinned toolchain:

```wl
MathlibInstallation[]["Toolchain"]
```

<!-- => "leanprover/lean4:v4.35.0" -->

The Mathlib commit:

```wl
MathlibInstallation[]["Revision"]
```

<!-- => "56a005855ea17e0b0958f73ec801ae140b0a1679" -->

## Applications

Link to Mathlib's documentation:

```wl
Hyperlink["Mathlib documentation", MathlibInstallation[]["DocumentationURL"]]
```
