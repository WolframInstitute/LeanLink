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

<code>[LeanFreeEnvironment]()[*handle*]</code> releases a Lean environment previously loaded with [LeanLoadEnvironment]().

<code>[LeanFreeEnvironment]()[*environment*]</code> releases an imported [LeanEnvironment](), with what its evaluations use.

## Details & Options

- *handle* is the integer returned by [LeanLoadEnvironment](). After freeing, the handle is no longer valid for queries.
- Freeing an environment invalidates every term and alias that shares its handle and removes cached queries for that handle. A later import creates a usable handle again.
- Temporary compiled files are deleted when no remaining environment depends on them.
- `"EvaluatorOnly" -> True` releases only what [LeanEvaluate]() uses: the state its evaluations start from, and its process with `"Isolated" -> True`. The environment and its terms stay available, and the next evaluation makes them again.
- Stopping an isolated evaluator releases that process's memory. Lean's embedded runtime retains imported module regions until the Wolfram kernel exits.
- Returns [Null]().

## Basic Examples

Import, evaluate and release a small definition:

```wl
env = LeanImportString["def square (n : Nat) := n*n"]
```

```wl
LeanEvaluate[env["square"], 5]
```

```wl
LeanFreeEnvironment[env]
```

---

Load the core `Init` module from the Lean toolchain and immediately free it:

```wl
toolchainLib = FileNameJoin[{$HomeDirectory, ".elan", "toolchains", "leanprover--lean4---v4.35.0", "lib", "lean"}];
If[ DirectoryQ[toolchainLib],
    handle = LeanLoadEnvironment[{"Init"}, toolchainLib];
    LeanFreeEnvironment[handle],
    "Lean toolchain not installed"
]
```

<!-- => Null (or "Lean toolchain not installed") -->

## Properties and Relations

[LeanFreeEnvironment]() is the release half of the [LeanLoadEnvironment]() handle lifecycle; the two bracket a block of repeated low-level queries.
