---
Template: Symbol
Name: LeanNoValue
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanNoValue
Keywords: [Lean, axiom, opaque, no value, body, CIC]
SeeAlso: [LeanValue, LeanConstant, LeanTruncated]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanNoValue]()[]</code> marks a constant that has no definition body - an `axiom` or an `opaque` declaration.

## Details & Options

- [LeanValue]() returns [LeanNoValue]()`[]` for a constant whose body is not a term (it is asserted, not defined). It renders as a placeholder glyph.

## Basic Examples

The marker for a body-less constant:

```wl
LeanNoValue[]
```

<!-- => renders as a placeholder (no body) -->
