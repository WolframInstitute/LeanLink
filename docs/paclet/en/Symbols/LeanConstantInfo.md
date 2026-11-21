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
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    LeanConstantInfo["And.comm",
        "Imports" -> {"Mathlib.Basic.Logic.Basic"}, "ProjectDir" -> mathlibDir],
    "Mathlib is not installed"
]
```

<!-- => LeanConstant["And.comm", "theorem", <type tree>, <term tree>] -->

## Properties and Relations

[LeanListConstants]() returns an [Association]() of [LeanConstant]() records for every constant in the loaded modules; [LeanConstantInfo]() is the single-name query.
