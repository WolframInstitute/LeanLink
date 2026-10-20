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

- *searchPath* lists every directory the modules' compiled `.olean` files come from, separated by `":"`: the project's own build directory (for a lake project, `<project>/.lake/build/lib/lean`), each dependency's, and the Lean toolchain's `lib/lean`, which holds `Init`. [LeanImport]() assembles this path for you from `"ProjectDir"`.
- The returned handle is a positive integer naming a native environment held open in the Lean runtime. A failed load returns `0`.
- Use the handle for many [LeanConstantInfo]() / [LeanExpr]() style queries against one loaded environment without reloading it each time, then release it with [LeanFreeEnvironment]().
- Most workflows use [LeanImport]() instead, which loads, queries, and wraps constants in one step. [LeanLoadEnvironment]() is the lower-level door for repeated queries where holding the environment open matters.

## Basic Examples

Load the core `Init` module from the Lean toolchain into an environment handle, then free it:

```wl
toolchainLib = FileNameJoin[{$HomeDirectory, ".elan", "toolchains", "leanprover--lean4---v4.35.0", "lib", "lean"}];
If[ DirectoryQ[toolchainLib],
    handle = LeanLoadEnvironment[{"Init"}, toolchainLib];
    result = handle > 0;
    LeanFreeEnvironment[handle];
    result,
    "Lean toolchain not installed"
]
```

<!-- => True (a positive handle is returned, then freed) -->

## Possible Issues

If *searchPath* omits a directory the modules need, the load fails and returns `0`: without the toolchain's `lib/lean` the error is `unknown module prefix 'Init'`. Test the handle with `handle > 0`, not [IntegerQ]().

A handle holds memory in the Lean runtime until released. Always pair [LeanLoadEnvironment]() with [LeanFreeEnvironment]() so long-running sessions do not accumulate open environments.
