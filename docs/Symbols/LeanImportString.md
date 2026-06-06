---
Template: Symbol
Name: LeanImportString
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanImportString
Keywords: [Lean, import, source, string, compile, environment, theorem]
SeeAlso: [LeanImport, LeanExportString, LeanEnvironment, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanImportString]()[*src*]</code> compiles a Lean 4 source string and returns a [LeanEnvironment]() of the constants it declares.

## Details & Options

- *src* is ordinary Lean 4 source: any mix of `def`, `theorem`, `inductive`, `structure`, and so on. Each top-level declaration becomes one [LeanTerm]() in the result.
- The string is elaborated by the embedded Lean runtime, so a type error in *src* surfaces as a [Failure]() the same way `lake build` would report it.
- Use [LeanImportString]() for ad-hoc definitions and round-trips; use [LeanImport]() to pull constants from a compiled module such as Mathlib.

## Basic Examples

Compile a single theorem:

```wl
imported = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Read back its type:

```wl
imported["myT"]["TypeForm"]
```

<!-- => "Nat.succ 0 = 1" -->

## Scope

Several declarations at once, separated by newlines:

```wl
env = LeanImportString["def double (n : Nat) : Nat := n + n
theorem myT : Nat.succ 0 = 1 := rfl"];
Keys[env]
```

<!-- => {"double", "myT"} -->

An inductive type:

```wl
defs = LeanImportString["inductive Dir where | L | R deriving Repr"];
defs["Dir"]["TypeForm"]
```

<!-- => "Type" -->

## Properties and Relations

[LeanImportString]() round-trips with [LeanExportString](): import source, query it, and export an environment back to Lean source.

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
src = LeanExportString[env];
Keys @ LeanImportString[src]
```

<!-- => {"myT"} -->
