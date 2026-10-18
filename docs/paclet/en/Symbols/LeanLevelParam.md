---
Template: Symbol
Name: LeanLevelParam
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelParam
Keywords: [Lean, universe, level, parameter, polymorphism]
SeeAlso: [LeanLevelMax, LeanLevelMVar, LeanSort, LeanConst]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelParam]()[*name*]</code> is a named universe parameter, such as `u` or `v`.

## Details & Options

- Universe-polymorphic constants are parameterized over level variables; [LeanLevelParam]() names one. The universe arguments of a [LeanConst]() are typically [LeanLevelParam]()s.

## Basic Examples

A universe parameter:

```wl
LeanLevelParam["u"]
```

<!-- => renders as: u -->

A universe-polymorphic constant carrying it:

```wl
LeanConst["List", {LeanLevelParam["u"]}]
```

<!-- => renders as: List.{u} -->
