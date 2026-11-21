---
Template: Symbol
Name: LeanListConstants
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanListConstants
Keywords: [Lean, constants, list, association, query, filter]
SeeAlso: [LeanConstantInfo, LeanConstant, LeanImport]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanListConstants]()[]</code> lists every constant in the loaded modules as an [Association]() from name to [LeanConstant]().

## Details & Options

- Options: `"ProjectDir"`, `"Imports"`, and `"Filter"` (keep only names containing the substring).
- [LeanListConstants]() returns raw [LeanConstant]() records; [LeanImport]() returns the same constants wrapped as [LeanTerm]()s in a [LeanEnvironment]() with the richer property interface.

## Basic Examples

List a filtered slice of a Mathlib module (gated on a built checkout):

```wl
mathlibDir = MathlibInstallation[]["Directory"];
If[ MathlibInstallation[]["Status"] === "Ready",
    Keys @ LeanListConstants["Imports" -> {"Mathlib.Basic.Logic.Basic"},
        "ProjectDir" -> mathlibDir, "Filter" -> "And.comm"],
    "Mathlib is not installed"
]
```

<!-- => {"And.comm"} -->

## Possible Issues

Listing a Mathlib module without a `"Filter"` returns tens of thousands of constants. Always narrow with `"Filter"` (or prefer [LeanImport]() with a filter) when exploring large modules.
