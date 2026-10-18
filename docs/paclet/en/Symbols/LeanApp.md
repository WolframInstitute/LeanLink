---
Template: Symbol
Name: LeanApp
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanApp
Keywords: [Lean, application, function, expression, CIC]
SeeAlso: [LeanConst, LeanLam, LeanForall, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanApp]()[*fn*, *arg*]</code> represents Lean function application - *fn* applied to *arg*.

## Details & Options

- Application is binary; a multi-argument call is nested, mirroring Lean's curried application: `f a b` is `LeanApp[LeanApp[f, a], b]`.
- [LeanApp]() renders by juxtaposition, like Lean source: `fn arg`.

## Basic Examples

Apply the successor function to a literal:

```wl
LeanApp[LeanConst["Nat.succ"], LeanLitNat[0]]
```

<!-- => renders as: Nat.succ 0 -->

---

A two-argument application nests left:

```wl
LeanApp[LeanApp[LeanConst["Nat.add"], LeanLitNat[2]], LeanLitNat[3]]
```

<!-- => renders as: Nat.add 2 3 -->

## Properties and Relations

Bound to an environment, an applied expression type-checks - `Nat.succ 42 : Nat`:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
LeanTerm[LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]], env]["TypeForm"]
```

<!-- => "Nat" -->
