---
Template: Symbol
Name: LeanConstantInfo
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanConstantInfo
Keywords: [Lean, constant, info, kind, type, term, query]
SeeAlso: [LeanConstant, LeanExpr, LeanValue, LeanListConstants]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanConstantInfo]()[*name*]</code> returns full information about the Lean constant *name* as a [LeanConstant]()`[name, kind, type, term]`.

## Details & Options

- Combines what [LeanExpr]() (the type) and [LeanValue]() (the body) return, plus the declaration *kind*, in a single [LeanConstant]() record.
- Options: `"ProjectDir"` and `"Imports"`.

## Basic Examples

Full info for a Mathlib theorem (gated on a built checkout):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    LeanConstantInfo["And.comm",
        "Imports" -> {"Mathlib.Logic.Basic"}, "ProjectDir" -> mathlibDir],
    "Mathlib not built"
]
```

<!-- => LeanConstant["And.comm", "theorem", <type tree>, <term tree>] -->

## Properties and Relations

[LeanListConstants]() returns an [Association]() of [LeanConstant]() records for every constant in the loaded modules; [LeanConstantInfo]() is the single-name query.
