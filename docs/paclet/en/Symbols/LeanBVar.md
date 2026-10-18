---
Template: Symbol
Name: LeanBVar
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanBVar
Keywords: [Lean, bound variable, de Bruijn, index, binder, CIC]
SeeAlso: [LeanForall, LeanLam, LeanFVar]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanBVar]()[*index*]</code> represents a bound variable by its de Bruijn *index*, where `0` is the innermost enclosing binder.

## Details & Options

- A [LeanBVar]() is meaningful only inside a binder ([LeanForall]() or [LeanLam]()): index `0` refers to the nearest binder, `1` to the next one out, and so on.
- It renders as `#index`.

## Basic Examples

The innermost bound variable:

```wl
LeanBVar[0]
```

<!-- => renders as: #0 (tooltip "bound var 0") -->

Inside `λ (x : Nat) => x`, the body is the bound variable `#0`:

```wl
LeanLam["x", LeanConst["Nat"], LeanBVar[0], "default"]
```

<!-- => renders as: fun (x : Nat) => #0 -->
