---
Template: Symbol
Name: LeanLam
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanLam
Keywords: [Lean, lambda, abstraction, function, binder, CIC]
SeeAlso: [LeanForall, LeanApp, LeanBVar, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanLam]()[*name*, *type*, *body*, *binder*]</code> represents a Lean `λ`-abstraction binding *name* of type *type* over *body*.

## Details & Options

- *binder* is the bracket kind, as for [LeanForall](): `"default"`, `"implicit"`, `"instImplicit"`, `"strictImplicit"`.
- Where [LeanForall]() is the function *type*, [LeanLam]() is the function *value*. It renders as Lean `fun (x : T) => body`, with [LeanBVar]() referring back to the binder.

## Basic Examples

The identity function on naturals, `fun (x : Nat) => x`:

```wl
LeanLam["x", LeanConst["Nat"], LeanBVar[0], "default"]
```

<!-- => renders as: fun (x : Nat) => #0 -->

## Properties and Relations

A proof term is a [LeanLam]() - the identity proof's body is `fun x hp => hp`:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["id_proof"]["Term"] // Head
```

<!-- => LeanLam -->
