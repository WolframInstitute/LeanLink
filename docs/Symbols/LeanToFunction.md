---
Template: Symbol
Name: LeanToFunction
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanToFunction
Keywords: [Lean, function, Typed, FunctionCompile, convert, native]
SeeAlso: [LeanCompile, LeanCompileTyped, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanToFunction]()[*term*]</code> converts a [LeanTerm]() with compilable types into a [Function]() whose arguments are [Typed](), suitable for [FunctionCompile]().

## Details & Options

- [LeanToFunction]() is the lowering step that [LeanCompile]() feeds to [FunctionCompile](): it produces the uncompiled [Function]() so you can inspect or modify it before compiling.
- Each Lean argument type becomes a [Typed]() slot with the corresponding Wolfram compiler type (`Nat`/`Int` to `"MachineInteger"`, and so on).

## Basic Examples

Turn a Lean definition into a typed [Function]():

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"];
LeanToFunction[addEnv["myAdd"]]
```

<!-- => Function[{Typed[x$, "MachineInteger"], Typed[y$, "MachineInteger"]}, x$ + y$] (argument names are fresh) -->

## Properties and Relations

[LeanCompile]() is [LeanToFunction]() followed by [FunctionCompile]():

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"];
FunctionCompile[LeanToFunction[addEnv["myAdd"]]][3, 4]
```

<!-- => 7 -->
