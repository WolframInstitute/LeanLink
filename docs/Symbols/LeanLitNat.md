---
Template: Symbol
Name: LeanLitNat
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLitNat
Keywords: [Lean, literal, natural number, Nat, CIC]
SeeAlso: [LeanLitStr, LeanConst, LeanApp]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLitNat]()[*n*]</code> represents a Lean natural-number literal *n*.

## Details & Options

- *n* is a non-negative integer. It renders as the number itself.

## Basic Examples

A natural-number literal:

```wl
LeanLitNat[42]
```

<!-- => renders as: 42 -->

As the argument of an application, `Nat.succ 42`:

```wl
LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]]
```

<!-- => renders as: Nat.succ 42 -->
