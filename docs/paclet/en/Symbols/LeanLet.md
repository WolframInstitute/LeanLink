---
Template: Symbol
Name: LeanLet
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLet
Keywords: [Lean, let, binding, local definition, CIC]
SeeAlso: [LeanLam, LeanBVar, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLet]()[*name*, *type*, *value*, *body*]</code> represents a Lean `let`-binding: `let name : type := value; body`.

## Details & Options

- The bound *name* is in scope in *body*, referred to by a [LeanBVar]() de Bruijn index.
- It renders as Lean `let` syntax.

## Basic Examples

Bind a local and use it in the body:

```wl
LeanLet["x", LeanConst["Nat"], LeanLitNat[5], LeanBVar[0]]
```

<!-- => renders as: let x : Nat := 5; #0 -->
