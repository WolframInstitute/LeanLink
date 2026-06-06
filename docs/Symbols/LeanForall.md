---
Template: Symbol
Name: LeanForall
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanForall
Keywords: [Lean, forall, Pi, dependent, arrow, function type, binder, CIC]
SeeAlso: [LeanLam, LeanApp, LeanSort, LeanBVar, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanForall]()[*name*, *domain*, *body*, *binder*]</code> represents a Lean `∀` quantifier, equivalently a dependent function (`->`) type binding *name* of type *domain* over *body*.

## Details & Options

- *binder* is the bracket kind: `"default"` (explicit `(x : T)`), `"implicit"` (`{x : T}`), `"instImplicit"` (instance `[x : T]`), or `"strictImplicit"`.
- A non-dependent arrow `A -> B` is a [LeanForall]() whose *name* is `"_"` and whose *body* does not mention the bound variable.
- It renders in Lean binder notation; the body refers back to the binder with a [LeanBVar]() de Bruijn index.

## Basic Examples

A universally quantified proposition, `∀ (P : Prop), P`:

```wl
LeanForall["P", LeanSort[LeanLevelZero[]], LeanBVar[0], "default"]
```

<!-- => renders in Lean ∀-notation with an explicit (P : Prop) binder -->

An implicit binder uses braces, `{a : G}`:

```wl
LeanForall["a", LeanConst["G"], LeanBVar[0], "implicit"]
```

<!-- => renders with an implicit {a : G} binder -->

## Properties and Relations

A theorem's type is a chain of [LeanForall]()s - here the identity proof `∀ (P : Prop) (a : P), P`:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["id_proof"]["Type"] // Head
```

<!-- => LeanForall -->
