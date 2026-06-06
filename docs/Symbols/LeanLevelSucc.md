---
Template: Symbol
Name: LeanLevelSucc
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLevelSucc
Keywords: [Lean, universe, level, successor, Type]
SeeAlso: [LeanLevelZero, LeanSort, LeanLevelMax]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLevelSucc]()[*level*]</code> is the successor of a universe *level*.

## Details & Options

- <code>[LeanSort]()[[LeanLevelSucc]()[[LeanLevelZero]()[]]]</code> is `Type` (= `Sort 1`); applying [LeanLevelSucc]() again gives `Type 1`, and so on.

## Basic Examples

The successor of level zero:

```wl
LeanLevelSucc[LeanLevelZero[]]
```

<!-- => renders as: 0+1 -->

The sort it indexes is `Type`:

```wl
LeanSort[LeanLevelSucc[LeanLevelZero[]]]
```

<!-- => renders as: Type -->
