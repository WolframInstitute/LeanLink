---
Template: Symbol
Name: LeanLoadEnvironment
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLoadEnvironment
Keywords: [Lean, environment, handle, load, repeated queries, memory]
SeeAlso: [LeanFreeEnvironment, LeanImport, LeanConstantInfo]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLoadEnvironment]()[{*"Module1"*, ...}, *searchPath*]</code> loads a Lean environment from the given modules and returns an integer handle for repeated low-level queries.

## Details & Options

- *searchPath* is the directory holding the compiled `.olean` files (for a lake project, typically `<project>/.lake/build/lib/lean`). The returned handle is an integer naming a native environment held open in the Lean runtime.
- Use the handle for many [LeanConstantInfo]() / [LeanExpr]() style queries against one loaded environment without reloading it each time, then release it with [LeanFreeEnvironment]().
- Most workflows use [LeanImport]() instead, which loads, queries, and wraps constants in one step. [LeanLoadEnvironment]() is the lower-level door for repeated queries where holding the environment open matters.

## Basic Examples

Load a Mathlib module into an environment handle, then free it (gated on a built checkout):

```wl
leanLib = FileNameJoin[{$HomeDirectory, "src", "mathlib4", ".lake", "build", "lib", "lean"}];
If[ DirectoryQ[leanLib],
    handle = LeanLoadEnvironment[{"Mathlib.Logic.Basic"}, leanLib];
    result = IntegerQ[handle];
    LeanFreeEnvironment[handle];
    result,
    "Mathlib not built"
]
```

<!-- => True (an integer handle is returned, then freed) -->

## Possible Issues

A handle holds memory in the Lean runtime until released. Always pair [LeanLoadEnvironment]() with [LeanFreeEnvironment]() so long-running sessions do not accumulate open environments.
