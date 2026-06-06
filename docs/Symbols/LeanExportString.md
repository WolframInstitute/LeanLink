---
Template: Symbol
Name: LeanExportString
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanExportString
Keywords: [Lean, export, source, string, environment, ProofToLean]
SeeAlso: [LeanExport, LeanImportString, ProofToLean, LeanEnvironment]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanExportString]()[*env*]</code> converts a [LeanEnvironment]() to a Lean 4 source-code string.

## Details & Options

- Each constant is emitted as a Lean declaration of its type, in declaration order. An environment produced by [ProofToLean]() carries structured tactic proofs, which export as faithful `:= by ...` blocks.
- For a constant whose body cannot be reconstructed as source (a term imported from compiled `.olean` data), the body is written as `sorry` - the declaration's *type* is still exported exactly.
- Use [LeanExport]() to write the same text directly to a `.lean` file.

## Basic Examples

Export a transpiled proof - the cleanest round-trip, since [ProofToLean]() emits real tactic bodies:

```wl
leanEnv = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
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

## Scope

Exporting an imported environment renders each declaration's type, with `sorry` standing in for bodies that are not reconstructible from compiled data:

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
LeanExportString[env]
```

<!-- => "theorem myT : (Nat.succ (OfNat.ofNat Nat 0 (instOfNatNat 0))) = (OfNat.ofNat Nat 1 (instOfNatNat 1)) := sorry" -->

## Properties and Relations

[LeanExportString]() round-trips with [LeanImportString](): exported source re-imports to the same constant names.

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
Keys @ LeanImportString @ LeanExportString[env]
```

<!-- => {"myT"} -->
