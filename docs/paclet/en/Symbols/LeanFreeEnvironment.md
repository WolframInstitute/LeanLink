---
Template: Symbol
Name: LeanFreeEnvironment
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanFreeEnvironment
Keywords: [Lean, environment, handle, free, release, memory]
SeeAlso: [LeanLoadEnvironment, LeanImport]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanFreeEnvironment]()[*handle*]</code> frees a Lean environment previously loaded with [LeanLoadEnvironment](), releasing its memory in the Lean runtime.

## Details & Options

- *handle* is the integer returned by [LeanLoadEnvironment](). After freeing, the handle is no longer valid for queries.
- Returns [Null]().

## Basic Examples

Load the core `Init` module from the Lean toolchain and immediately free it:

```wl
toolchainLib = FileNameJoin[{$HomeDirectory, ".elan", "toolchains", "leanprover--lean4---v4.30.0", "lib", "lean"}];
If[ DirectoryQ[toolchainLib],
    handle = LeanLoadEnvironment[{"Init"}, toolchainLib];
    LeanFreeEnvironment[handle],
    "Lean toolchain not installed"
]
```

<!-- => Null (or "Lean toolchain not installed") -->

## Properties and Relations

[LeanFreeEnvironment]() is the release half of the [LeanLoadEnvironment]() handle lifecycle; the two bracket a block of repeated low-level queries.
