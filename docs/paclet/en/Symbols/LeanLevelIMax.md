---
Template: Symbol
Name: LeanLevelIMax
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelIMax
Keywords: [Lean, universe, level, imax, impredicative]
SeeAlso: [LeanLevelMax, LeanLevelSucc, LeanLevelParam]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelIMax]()[*a*, *b*]</code> is the impredicative maximum of universe levels *a* and *b* - it is `0` whenever *b* is `0`, and `max a b` otherwise.

## Details & Options

- The `imax` rule is what makes `Prop` impredicative: a `∀` whose codomain is in `Prop` (level `0`) stays in `Prop`, regardless of the domain's level. Lean uses [LeanLevelIMax]() for the level of a dependent function type.

## Basic Examples

The impredicative max of two universe parameters:

```wl
LeanLevelIMax[LeanLevelParam["u"], LeanLevelParam["v"]]
```

<!-- => renders as: imax(u, v) -->
