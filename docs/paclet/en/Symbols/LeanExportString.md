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

- Each constant is emitted as a Lean declaration of its type: a theorem as a `theorem`, an axiom as an `axiom`, and any other constant, definition, inductive type or constructor, as a `def`. The constants come in an order where each follows those its type names.
- A constant imported from compiled `.olean` data has no body that can be written back, so its body is `sorry`, and its *type* is exported exactly: every constant applied with `@` and every argument written, implicit ones included, raw literals as `nat_lit`, and each bound variable named by its binder, renamed where that name is taken. Compiled again, the source declares the same constants with the same types.
- An environment produced by [ProofToLean]() carries structured tactic proofs, which export as faithful `:= by ...` blocks.
- Use [LeanExport]() to write the same text directly to a `.lean` file.

## Basic Examples

A proof found by [FindEquationalProof](), transpiled to Lean:

```wl
leanEnv = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]]
```

<!-- => LeanEnvironment summary box: 5 constants -->

Export a transpiled proof - the cleanest round-trip, since [ProofToLean]() emits real tactic bodies:

```wl
LeanExportString[leanEnv]
```

<!-- =>
axiom U : Type

axiom Ax1 : ∀ (b : U) (a : U), b = a
axiom Ax2 : ∀ (b : U) (c : U), b = c
axiom Hyp1 : ∀ (a : U) (c : U), a = c
theorem SL1 : ∀ (a : U) (c : U), a = c := by
  intro a c
  have h := Ax2 a c
  conv at h => lhs; simp only [Ax1]
  exact h

theorem FinalGoal : ∀ (a : U) (c : U), a = c := by
  intro a c
  exact SL1 a c
-->

## Scope

A Lean theorem, compiled from source:

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Exporting an imported environment renders each declaration's type, with `sorry` standing in for bodies that are not reconstructible from compiled data:

```wl
LeanExportString[env]
```

<!-- => "theorem myT : (@Nat.succ (@OfNat.ofNat Nat (nat_lit 0) (@instOfNatNat (nat_lit 0)))) = (@OfNat.ofNat Nat (nat_lit 1) (@instOfNatNat (nat_lit 1))) := sorry" -->

## Properties and Relations

A Lean theorem, compiled from source:

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

[LeanExportString]() round-trips with [LeanImportString](): exported source re-imports to the same constant names.

```wl
Keys @ LeanImportString @ LeanExportString[env]
```

<!-- => {"myT"} -->
