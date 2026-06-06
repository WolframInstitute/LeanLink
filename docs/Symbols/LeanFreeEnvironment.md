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

Load and immediately free an environment (gated on a built mathlib4 checkout):

```wl
leanLib = FileNameJoin[{$HomeDirectory, "src", "mathlib4", ".lake", "build", "lib", "lean"}];
If[ DirectoryQ[leanLib],
    handle = LeanLoadEnvironment[{"Mathlib.Logic.Basic"}, leanLib];
    LeanFreeEnvironment[handle],
    "Mathlib not built"
]
```

<!-- => Null (or "Mathlib not built") -->

## Properties and Relations

[LeanFreeEnvironment]() is the release half of the [LeanLoadEnvironment]() handle lifecycle; the two bracket a block of repeated low-level queries.
