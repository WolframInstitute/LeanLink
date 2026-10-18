---
Template: Symbol
Name: LeanExpr
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanExpr
Keywords: [Lean, type, expression, tree, constant, query]
SeeAlso: [LeanValue, LeanConstantInfo, LeanTerm, LeanImport]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanExpr]()[*name*]</code> returns the type of the Lean constant *name* as a symbolic expression tree.

## Details & Options

- The result is a tree of CIC heads ([LeanForall](), [LeanApp](), [LeanConst](), [LeanSort](), [LeanBVar](), ...) which render in Lean notation.
- Options: `"ProjectDir"` (the lake project), `"Imports"` (modules to load), and `"Depth"` (the expression-tree depth before a subtree becomes [LeanTruncated](), default `100`).
- [LeanExpr]() queries a single constant; to load many at once into a [LeanEnvironment]() use [LeanImport](), after which <code>*env*["*name*"]["Type"]</code> gives the same tree.

## Basic Examples

The type of a Mathlib theorem as an expression tree (gated on a built checkout):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    LeanExpr["And.comm",
        "Imports" -> {"Mathlib.Logic.Basic"}, "ProjectDir" -> mathlibDir],
    "Mathlib not built"
]
```

<!-- => LeanForall[...] rendering as ∀ {a : Prop} {b : Prop}, a ∧ b ⇔ b ∧ a -->

## Properties and Relations

[LeanExpr]() returns the type; [LeanValue]() returns the body; [LeanConstantInfo]() returns both together as a [LeanConstant]().
