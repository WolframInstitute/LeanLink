---
Template: Symbol
Name: $LeanNotation
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/$LeanNotation
Keywords: [Lean, TypeTheory, notation, display, MakeBoxes]
SeeAlso: [LeanToTypeTheory, TypeTheoryToLean]
RelatedGuides: [LeanLink]
---

## Usage

<code>[$LeanNotation]()</code> gives whether terms imported from Lean with [LeanToTypeTheory]() are displayed in Wolfram Language notation.

## Details & Options

- A statement imported from Lean reads in Lean's names: `a % b = 0` is `"Eq"["HMod.hMod"["a", "b"], "OfNat.ofNat"[0]]`. With [$LeanNotation]() [True](), the default, TypeTheory displays it as `a mod b == 0`.
- The notation is put in place when the bridge loads, at the first [LeanToTypeTheory]() or [TypeTheoryToLean]().
- These constants have a notation:

| Lean | Displayed as |
|---|---|
| `Eq`, `Ne` | `a == b`, `a != b` |
| `LT.lt`, `LE.le`, `GT.gt`, `GE.ge` | `a < b`, `a <= b`, `a > b`, `a >= b` |
| `HAdd.hAdd`, `HSub.hSub`, `HMul.hMul`, `HDiv.hDiv`, `HPow.hPow` | `a + b`, `a - b`, `a b`, `a / b`, `a ^ b` |
| `HMod.hMod` | `a mod b` |
| `Nat.add`, `Nat.sub`, `Nat.mul`, `Nat.div`, `Nat.mod`, `Nat.pow` | as the operations above |
| `Neg.neg` | `-a` |
| `OfNat.ofNat` | the numeral |
| `Nat.succ` | `n + 1` |
| `And`, `Or`, `Not`, `Iff` | `a && b`, <code>a &#124;&#124; b</code>, `!a`, `a ⧦ b` |
| `Exists` | `∃` with the variable and its type below it, from TypeTheory 0.45 |

- A term is rewritten as a whole before it is displayed, so an operand gets the parentheses its operator needs: `(a + b) (c mod d)`.
- Only the display changes: the term, its type check and what [TypeTheoryToLean]() writes are the same.
- A constant given other arguments than its notation takes is shown in Lean's names.
- The notation is given by rules of [MakeBoxes]() for [StandardForm]() and [TraditionalForm](), which also show an expression of the same form, such as `"Eq"[1, 2]`, outside a term.

## Basic Examples

Import a theorem about remainders from Lean:

```wl
lean = LeanImportString["theorem remainderZero (a b : Nat) (h : a % b = 0) : a % b = 0 := h"]
```

```wl
env = LeanToTypeTheory[lean, "remainderZero"]
```

Its statement is displayed with `mod` and `==`:

```wl
env["remainderZero"]
```

Show it in Lean's names:

```wl
Block[{$LeanNotation = False}, ToString[env["remainderZero"], StandardForm]]
```
