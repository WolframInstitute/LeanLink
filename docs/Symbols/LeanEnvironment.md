---
Template: Symbol
Name: LeanEnvironment
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanEnvironment
Keywords: [Lean, environment, constants, association, Mathlib]
SeeAlso: [LeanImport, LeanImportString, LeanTerm, ProofToLean, LeanState]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanEnvironment]()[*assoc*]</code> holds a collection of named Lean constants, where *assoc* maps each name to a [LeanTerm]().

## Details & Options

- A [LeanEnvironment]() is produced by [LeanImport](), [LeanImportString](), or [ProofToLean]() - you rarely build one by hand.
- Index it by constant name to get a [LeanTerm](): <code>*env*["mul_comm"]</code>. It also supports [Keys](), [Values](), [Length](), [KeyExistsQ](), and [Normal]() (which returns the underlying [Association]()).
- <code>[Information]()[*env*, *prop*]</code> exposes environment metadata. Properties: `"Constants"` (the names), `"Kinds"` (a count by declaration kind), `"Handle"` (the native environment id), `"Source"`, `"DeclOrder"`, `"Preamble"`.

## Basic Examples

Import the bundled environment:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 25 constants -->

Its size and constant names:

```wl
Length[env]
```

<!-- => 25 -->

```wl
Keys[env]
```

<!-- => {"Vec.head", "id_proof", "add_zero_term", "fin_example", "add_comm_proof", ...} -->

Index a constant by name to get a [LeanTerm]():

```wl
env["id_proof"]
```

<!-- => LeanTerm summary box: Name id_proof, Kind theorem -->

## Scope

The available metadata properties:

```wl
Information[env, "Properties"]
```

<!-- => {"Constants", "Kinds", "Handle", "Source", "DeclOrder", "Preamble"} -->

How many constants of each kind:

```wl
Information[env, "Kinds"]
```

<!-- => <|"def" -> 6, "theorem" -> 18, "inductive" -> 1|> -->

## Properties and Relations

[Normal]() recovers the underlying [Association]() of [LeanTerm]() values:

```wl
Head @ Normal[env]
```

<!-- => Association -->
