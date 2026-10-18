---
Template: TechNote
Name: LeanLinkIntro
Title: Getting Started with LeanLink
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/LeanLinkIntro
Keywords: [Lean, LeanLink, getting started, import, proof, tactic, ProofToLean]
RelatedGuides: [LeanLink]
RelatedTutorials: [ExploringMathlib, ImportGraph]
---

LeanLink embeds the [Lean 4](https://lean-lang.org/) theorem prover in the Wolfram Language. This tutorial loads a small bundled environment, inspects Lean types and proof terms, runs interactive tactic proofs, and round-trips proofs between the two systems. One environment is imported up front and reused throughout.

## Importing a Lean Environment

[LeanImport]() loads the constants of a compiled Lean module or `.lean` file into a [LeanEnvironment](). Here we load the example file bundled with the paclet:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 25 constants -->

It holds a handful of definitions and proofs:

```wl
Keys[env]
```

<!-- => {"Vec.head", "id_proof", "add_zero_term", "fin_example", "add_comm_proof", "contrapositive", ...} -->

## Inspecting Types and Terms

Index the environment by name to get a [LeanTerm](). Its `"TypeForm"` is the proposition it proves (or the type it inhabits), pretty-printed as Lean source:

```wl
env["id_proof"]["TypeForm"]
```

<!-- => "∀ (P : Prop) (a : P), P" -->

The `"TermForm"` is the proof term itself:

```wl
env["id_proof"]["TermForm"]
```

<!-- => "fun x hp => hp" -->

Behind the pretty-print is a symbolic expression tree, built from the CIC heads [LeanForall](), [LeanApp](), [LeanConst](), [LeanSort](), and friends. The `"Type"` property returns it:

```wl
env["id_proof"]["Type"]
```

<!-- => LeanForall["P", LeanSort[LeanLevelZero[]], LeanForall[...], "default"] (renders in Lean notation) -->

A dependent type from the same file - the head of a length-indexed vector:

```wl
env["Vec.head"]["TypeForm"]
```

<!-- => "∀ {α : Type} {n : Nat} (a : Vec α n + 1), α" -->

## Expression Graphs

Every expression is a tree, and `"ExprGraph"` draws it as a [Graph]():

```wl
env["modus_ponens"]["ExprGraph"]
```

<!-- => Graph of the modus_ponens type/term tree -->

## Constructing Expressions

You can build a Lean expression from the CIC heads and bind it to an environment for type-checking with <code>[LeanTerm]()[*expr*, *env*]</code>. Applying `Nat.succ` to a literal:

```wl
t = LeanTerm[LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]], env];
t["TypeForm"]
```

<!-- => "Nat" -->

A [LeanForall]() builds a function type; as a term, its own type is a universe:

```wl
LeanTerm[LeanForall["n", LeanConst["Nat"], LeanConst["Nat"], "default"], env]["TypeForm"]
```

<!-- => "Type" -->

## Interactive Tactic Proofs

[LeanState]() opens a theorem as a goal; a [LeanTactic]() advances it. Take the identity $\forall P : \mathrm{Prop},\; P \to P$:

```wl
s0 = LeanState[env["id_proof"]]
```

<!-- => LeanState summary box, 1 goal -->

Introduce the proposition and hypothesis, then close with the hypothesis:

```wl
s1 = LeanTactic["intro P"][s0];
s2 = LeanTactic["intro h"][s1];
s3 = LeanTactic["exact h"][s2];
s3["Complete"]
```

<!-- => True -->

### Modus ponens: $P \to (P \to Q) \to Q$

A whole proof as one tactic sequence:

```wl
LeanTactic[{"intro P Q hP hPQ", "exact hPQ hP"}][LeanState[env["modus_ponens"]]]["Complete"]
```

<!-- => True -->

### Contrapositive: $(P \to Q) \to (\neg Q \to \neg P)$

```wl
LeanTactic[{"intro P Q hPQ hnQ hP", "apply hnQ", "exact hPQ hP"}][LeanState[env["contrapositive"]]]["Complete"]
```

<!-- => True -->

### And commutativity: $P \land Q \to Q \land P$

`constructor` splits the conjunction goal into two:

```wl
s0 = LeanState[env["and_comm_proof"]];
LeanTactic["constructor"][LeanTactic["intro P Q h"][s0]]["GoalCount"]
```

<!-- => 2 -->

## Goal Properties

A [LeanState]() exposes its goal stack. Each goal is a [LeanGoal]() with a `"Target"` and a `"Context"`:

```wl
s0 = LeanState[env["id_proof"]];
s0["Goals"][[1]]["Target"]
```

<!-- => "∀ (P : Prop), P → P" -->

```wl
s0["Complete"]
```

<!-- => False -->

## The Environment

A [LeanEnvironment]() supports [Keys](), [Length](), and [Information](). The kind breakdown of our example file:

```wl
Information[env, "Kinds"]
```

<!-- => <|"def" -> 6, "theorem" -> 18, "inductive" -> 1|> -->

## Exporting to Lean Source

[LeanExportString]() renders a constant's type back as Lean source (bound variables in a bare type print as de Bruijn indices `#0`, `#1`):

```wl
LeanExportString[env["id_proof"]]
```

<!-- => "∀ (P : Prop) (a : #0), #1" -->

## Importing from a Source String

[LeanImportString]() compiles Lean source on the fly:

```wl
imported = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
imported["myT"]["TypeForm"]
```

<!-- => "Nat.succ 0 = 1" -->

## Transpiling a Wolfram Proof

[ProofToLean]() turns a Wolfram [ProofObject]() into a checkable [LeanEnvironment]() of axioms, lemmas, and a final theorem:

```wl
leanEnv = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
Keys[leanEnv]
```

<!-- => {"Ax1", "Ax2", "Hyp1", "SL1", "FinalGoal"} -->

The transpiled goal re-checks - opening it with [LeanState]() drives it to completion:

```wl
LeanState[leanEnv["FinalGoal"]]["Complete"]
```

<!-- => True -->

The whole thing as Lean source:

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

## Importing from Mathlib

[LeanImport]() reads any built Lean project. Point `"ProjectDir"` at a mathlib4 checkout where `lake exe cache get && lake build Mathlib.Algebra.Group.Basic` has run (gated so this page builds without Mathlib):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    LeanImport["Mathlib.Algebra.Group.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "mul_comm"]["mul_comm"]["TypeForm"],
    "Mathlib not built - see the Exploring Mathlib tutorial"
]
```

<!-- => "∀ {G : Type u_1} [inst : CommMagma G] (a : G) (b : G), a * b = b * a" -->

The [Exploring Mathlib](paclet:Wolfram/LeanLink/tutorial/ExploringMathlib) tutorial goes deeper into types, binders, and typeclasses.

## Structured Tactics

Tactics can also be built structurally, with Lean-native names and Wolfram-valued arguments:

```wl
LeanTactic["exact", LeanConst["h"]]
```

<!-- => LeanTactic["exact", LeanConst["h", {}]] -->

Applied the same way as string tactics:

```wl
s0 = LeanState[env["id_proof"]];
s1 = LeanTactic["intro", {"P"}][s0];
s2 = LeanTactic["intro", {"h"}][s1];
LeanTactic["exact", LeanConst["h"]][s2]["Complete"]
```

<!-- => True -->
