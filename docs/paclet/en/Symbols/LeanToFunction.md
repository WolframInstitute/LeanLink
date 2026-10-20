---
Template: Symbol
Name: LeanToFunction
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanToFunction
Keywords: [Lean, function, Typed, FunctionCompile, convert, native]
SeeAlso: [LeanCompile, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanToFunction]()[*term*]</code> converts a [LeanTerm]() with compilable types into a [Function]() whose arguments are [Typed](), suitable for [FunctionCompile]().

## Details & Options

- [LeanToFunction]() is the lowering step that [LeanCompile]() feeds to [FunctionCompile](): it produces the uncompiled [Function]() so you can inspect or modify it before compiling.
- Each Lean argument type becomes a [Typed]() slot with the corresponding Wolfram compiler type (`Nat`/`Int` to `"MachineInteger"`, and so on).
- Arithmetic, comparisons, Boolean connectives, `if` and `bif`, `max` and `min` become their Wolfram Language counterparts; a call to any other function stays in the body, as a symbol of its name or, for a name such as `"Nat.log2"` that is not a symbol name, as the [LeanConst]() itself.

## Basic Examples

A Lean definition, compiled from source:

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Turn a Lean definition into a typed [Function]():

```wl
LeanToFunction[addEnv["myAdd"]]
```

<!-- => Function[{Typed[x$, "MachineInteger"], Typed[y$, "MachineInteger"]}, x$ + y$] (argument names are fresh) -->

## Scope

A Lean definition with a condition, compiled from source:

```wl
clampEnv = LeanImportString["def clampTo (n hi : Nat) : Nat := if n != 0 && n < hi then n else min hi 1"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

The condition becomes [If]() with [Unequal]() and [And](), and `min` becomes [Min]():

```wl
LeanToFunction[clampEnv["clampTo"]]
```

<!-- => Function[{Typed[n$, "MachineInteger"], Typed[hi$, "MachineInteger"]}, If[n$ != 0 && n$ < hi$, n$, Min[1, hi$]]] -->

---

A definition that calls a function with no Wolfram Language counterpart, compiled from source:

```wl
logEnv = LeanImportString["def logPlusOne (n : Nat) : Nat := Nat.log2 n + 1"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

The call stays in the body as the [LeanConst](), so the function does not compile:

```wl
LeanToFunction[logEnv["logPlusOne"]]
```

<!-- => Function[Typed[n$, "MachineInteger"], 1 + Nat.log2[n$]], with Nat.log2 the LeanConst shown as Lean writes it -->

## Properties and Relations

A Lean definition, compiled from source:

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

[LeanCompile]() is [LeanToFunction]() followed by [FunctionCompile]():

```wl
FunctionCompile[LeanToFunction[addEnv["myAdd"]]][3, 4]
```

<!-- => 7 -->
