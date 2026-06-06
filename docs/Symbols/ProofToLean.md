---
Template: Symbol
Name: ProofToLean
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/ProofToLean
Keywords: [Lean, proof, ProofObject, transpile, FindEquationalProof, theorem, tactic]
SeeAlso: [LeanExportString, LeanState, LeanEnvironment, LeanImportString]
RelatedGuides: [LeanLink]
---

## Usage

<code>[ProofToLean]()[*proof*]</code> transpiles a Wolfram [ProofObject]() into a [LeanEnvironment]() whose constants are the axioms, lemmas, and final theorem of the proof, with structured Lean tactic bodies.

## Details & Options

- *proof* is a [ProofObject]() such as the result of [FindEquationalProof](). Each premise becomes an `axiom`, each derived step a `theorem` with a tactic proof, and the goal the `"FinalGoal"` theorem.
- Types are carried as [LeanTerm]() expression trees; step proofs are emitted as Lean tactic blocks (`have`, `conv`, `simp only`, `exact`). The result therefore round-trips through [LeanExportString]() into compilable Lean source.
- Because the transpiled environment is real Lean, you can re-check it - opening the `"FinalGoal"` with [LeanState]() and confirming it auto-completes verifies the transpilation.

## Basic Examples

Transpile an equational proof:

```wl
proof = FindEquationalProof[a == c, {a == b, b == c}];
leanEnv = ProofToLean[proof]
```

<!-- => LeanEnvironment summary box: 5 constants -->

The generated constants - premises, derived step, and goal:

```wl
Keys[leanEnv]
```

<!-- => {"Ax1", "Ax2", "Hyp1", "SL1", "FinalGoal"} -->

The final goal's type:

```wl
leanEnv["FinalGoal"]["TypeForm"]
```

<!-- => "a = c" -->

## Scope

The whole transpiled environment as Lean 4 source:

```wl
LeanExportString[leanEnv]
```

<!-- =>
axiom U : Type

axiom a : U
axiom b : U
axiom c : U

axiom Ax1 : b = a
axiom Ax2 : b = c
axiom Hyp1 : a = c
theorem SL1 : a = c := by
  have h := Ax2
  conv at h => lhs; simp only [Ax1]
  exact h

theorem FinalGoal : a = c := by
  exact SL1
-->

## Properties and Relations

The transpiled goal re-checks: opening it with [LeanState]() and stepping the generated proof drives it to completion.

```wl
LeanState[leanEnv["FinalGoal"]]["Complete"]
```

<!-- => True -->

[ProofToLean]() is the Lean counterpart to [MetamathImport]() and similar bridges: it takes a proof produced in the Wolfram Language and renders it as an independently checkable artifact in an external prover.
