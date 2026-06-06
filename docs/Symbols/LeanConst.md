---
Template: Symbol
Name: LeanConst
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanConst
Keywords: [Lean, constant, reference, universe, expression, CIC]
SeeAlso: [LeanApp, LeanForall, LeanSort, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanConst]()[*name*, *universes*]</code> represents a reference to a declared constant *name* at the given universe levels.

<code>[LeanConst]()[*name*]</code> is shorthand for no universe arguments, `LeanConst[name, {}]`.

## Details & Options

- *name* is the fully qualified Lean name (`"Nat"`, `"Nat.succ"`, `"And"`). *universes* is a list of universe levels ([LeanLevelParam](), [LeanLevelZero](), ...) for a polymorphic constant.
- [LeanConst]() is one of the CIC expression heads that make up a [LeanTerm]()'s `"Type"` and `"Term"` trees; it renders as the bare constant name.

## Basic Examples

A reference to the natural-number type:

```wl
LeanConst["Nat"]
```

<!-- => renders as: Nat -->

A polymorphic constant carries its universe parameters:

```wl
LeanConst["List", {LeanLevelParam["u"]}]
```

<!-- => renders as: List.{u} -->

## Properties and Relations

Constants are the leaves of an applied expression - here `Nat.succ` applied to a literal:

```wl
LeanApp[LeanConst["Nat.succ"], LeanLitNat[0]]
```

<!-- => renders as: Nat.succ 0 -->
