---
Template: Symbol
Name: LeanTruncated
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanTruncated
Keywords: [Lean, truncated, depth, limit, expression, CIC]
SeeAlso: [LeanExpr, LeanValue, LeanNoValue]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanTruncated]()[*info*]</code> marks an expression that was cut off at the depth limit, with *info* describing what was elided.

## Details & Options

- When [LeanExpr]() / [LeanValue]() (or the `"Type"` / `"Term"` properties) hit their `"Depth"` limit, the deeper subtree is replaced by a [LeanTruncated]() node. Raise `"Depth"` to expand further.
- It renders as an ellipsis.

## Basic Examples

A truncation marker:

```wl
LeanTruncated["Nat"]
```

<!-- => renders as: … (tooltip "Nat") -->
