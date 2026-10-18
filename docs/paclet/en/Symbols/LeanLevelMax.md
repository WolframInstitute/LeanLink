---
Template: Symbol
Name: LeanLevelMax
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelMax
Keywords: [Lean, universe, level, max, maximum]
SeeAlso: [LeanLevelIMax, LeanLevelSucc, LeanLevelParam]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelMax]()[*a*, *b*]</code> is the maximum of two universe levels *a* and *b*.

## Details & Options

- A polymorphic definition combining two universes lives at their max; for example a pair type over `Sort u` and `Sort v` is at `max u v`.

## Basic Examples

The max of two universe parameters:

```wl
LeanLevelMax[LeanLevelParam["u"], LeanLevelParam["v"]]
```

<!-- => renders as: max(u, v) -->
