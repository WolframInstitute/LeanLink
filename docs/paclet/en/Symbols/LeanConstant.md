---
Template: Symbol
Name: LeanConstant
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanConstant
Keywords: [Lean, constant, raw, native, shim, kind, type]
SeeAlso: [LeanConstantInfo, LeanTerm, LeanListConstants]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanConstant]()[*name*, *kind*, *type*, *term*]</code> is the raw constant record returned by the native shim: the constant's name, its declaration kind, its type expression, and its body.

## Details & Options

- [LeanConstant]() is the low-level record [LeanConstantInfo]() returns and [LeanListConstants]() collects. The higher-level [LeanTerm]() wraps the same data with the property interface (`"TypeForm"`, `"ExprGraph"`, ...).
- *kind* is a string such as `"theorem"`, `"def"`, `"inductive"`, `"constructor"`, or `"axiom"`. *type* and *term* are CIC expression trees (or [LeanNoValue]() for a constant with no body).

## Basic Examples

The raw record of a Mathlib theorem (gated on a built checkout):

```wl
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    LeanConstantInfo["And.comm",
        "Imports" -> {"Mathlib.Basic.Logic.Basic"}, "ProjectDir" -> mathlibDir],
    "Mathlib is not installed"
]
```

<!-- => LeanConstant["And.comm", "theorem", <type tree>, <term tree>] -->

The name and kind are the first two parts:

```wl
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    info = LeanConstantInfo["And.comm",
        "Imports" -> {"Mathlib.Basic.Logic.Basic"}, "ProjectDir" -> mathlibDir];
    {info[[1]], info[[2]]},
    "Mathlib is not installed"
]
```

<!-- => {"And.comm", "theorem"} -->
