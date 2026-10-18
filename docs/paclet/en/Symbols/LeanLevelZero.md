---
Template: Symbol
Name: LeanLevelZero
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelZero
Keywords: [Lean, universe, level, zero, Prop]
SeeAlso: [LeanLevelSucc, LeanSort, LeanLevelParam]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelZero]()[]</code> is universe level `0` - the level of `Prop`.

## Details & Options

- Universe levels index Lean's hierarchy of sorts. <code>[LeanSort]()[[LeanLevelZero]()[]]</code> is `Prop`.

## Basic Examples

Level zero:

```wl
LeanLevelZero[]
```

<!-- => renders as: 0 -->

The sort it indexes is `Prop`:

```wl
LeanSort[LeanLevelZero[]]
```

<!-- => renders as: Prop -->
