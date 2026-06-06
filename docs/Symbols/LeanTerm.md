---
Template: Symbol
Name: LeanTerm
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanTerm
Keywords: [Lean, term, constant, type, proof, expression, properties]
SeeAlso: [LeanEnvironment, LeanConst, LeanForall, LeanState, LeanCompile]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanTerm]()[*assoc*]</code> represents one Lean constant - its name, kind, type, and body - as returned by indexing a [LeanEnvironment]().

<code>[LeanTerm]()[*expr*, *env*]</code> wraps a hand-built expression tree *expr*, bound to environment *env* so it can be type-checked.

## Details & Options

- A [LeanTerm]() renders as a summary box (icon, name, kind). Query it with properties via <code>*term*["*prop*"]</code>:

| Property | Result |
|---|---|
| `"Type"` / `"Term"` | the type / body as a symbolic expression tree |
| `"TypeForm"` / `"TermForm"` | the type / body pretty-printed as Lean source |
| `"Parameters"` | the binder chain (name, type, binder kind) as rows |
| `"TypeRefs"` / `"TermRefs"` | constants the type / body refers to |
| `"ExprGraph"` / `"CallGraph"` | a [Graph]() of the expression tree / dependencies |
| `"Name"` / `"Kind"` | the constant's name / declaration kind |

- The expression tree is built from the CIC heads [LeanConst](), [LeanApp](), [LeanForall](), [LeanLam](), [LeanBVar](), [LeanSort](), [LeanLitNat](), ... which carry box formatting, so a `"Type"` displays in Lean notation rather than as raw heads.

## Basic Examples

A constant from an imported environment:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["id_proof"]
```

<!-- => LeanTerm summary box: Name id_proof, Kind theorem -->

Its type as Lean source, and its proof body:

```wl
env["id_proof"]["TypeForm"]
```

<!-- => "∀ (P : Prop) (a : P), P" -->

```wl
env["id_proof"]["TermForm"]
```

<!-- => "fun x hp => hp" -->

The type as a symbolic tree (rendered in Lean notation by the [LeanForall]() boxes):

```wl
env["id_proof"]["Type"]
```

<!-- => LeanForall["P", LeanSort[LeanLevelZero[]], LeanForall[...], "default"] (renders as ∀ (P : Prop), P → P) -->

## Scope

The binder chain as a [Dataset]():

```wl
env["modus_ponens"]["Parameters"] // Dataset
```

<!-- => Dataset of 4 rows: P, Q (Prop, explicit), the two hypotheses -->

The expression tree as a graph:

```wl
env["id_proof"]["ExprGraph"]
```

<!-- => Graph (6 vertices) -->

## Properties and Relations

A hand-built expression, bound to an environment, type-checks against it:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
LeanTerm[LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]], env]["TypeForm"]
```

<!-- => "Nat" -->
