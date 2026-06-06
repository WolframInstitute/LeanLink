---
Template: Symbol
Name: LeanSort
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanSort
Keywords: [Lean, sort, universe, Prop, Type, level, CIC]
SeeAlso: [LeanLevelZero, LeanLevelSucc, LeanForall, LeanConst]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanSort]()[*level*]</code> represents a Lean universe at the given universe *level*.

## Details & Options

- <code>[LeanSort]()[[LeanLevelZero]()[]]</code> is `Prop` (the universe of propositions); <code>[LeanSort]()[[LeanLevelSucc]()[[LeanLevelZero]()[]]]</code> is `Type`.
- A polymorphic universe uses a [LeanLevelParam](): <code>[LeanSort]()[[LeanLevelParam]()["u"]]</code> is `Sort u`.

## Basic Examples

The universe of propositions:

```wl
LeanSort[LeanLevelZero[]]
```

<!-- => renders as: Prop -->

The first data universe:

```wl
LeanSort[LeanLevelSucc[LeanLevelZero[]]]
```

<!-- => renders as: Type -->

A universe-polymorphic sort:

```wl
LeanSort[LeanLevelParam["u"]]
```

<!-- => renders as: Sort u -->
