---
Template: Symbol
Name: LeanValue
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanValue
Keywords: [Lean, value, body, proof, definition, term, query]
SeeAlso: [LeanExpr, LeanConstantInfo, LeanTerm, LeanNoValue]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanValue]()[*name*]</code> returns the proof or definition body of the Lean constant *name* as a symbolic expression tree.

## Details & Options

- The body of a theorem is its proof term; the body of a `def` is its defining expression. A constant with no body (an `axiom` or `opaque`) yields [LeanNoValue]().
- Options match [LeanExpr](): `"ProjectDir"`, `"Imports"`, `"Depth"` (the tree depth before [LeanTruncated]()).

## Basic Examples

The proof term of a Mathlib theorem (gated on a built checkout):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    Head @ LeanValue["And.comm",
        "Imports" -> {"Mathlib.Logic.Basic"}, "ProjectDir" -> mathlibDir],
    "Mathlib not built"
]
```

<!-- => LeanLam (the proof term is a λ-abstraction) -->

## Properties and Relations

[LeanValue]() is the body counterpart of [LeanExpr]() (the type); both are bundled by [LeanConstantInfo]() and surfaced as the `"Term"` / `"Type"` properties of a [LeanTerm]().
