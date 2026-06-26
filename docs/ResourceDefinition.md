---
Template: Paclet
ResourceType: Paclet
Name: Wolfram/LeanLink
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
Description: Native link between Wolfram Language and Lean 4
ContributedBy: Nik Murzin
Keywords: [Lean, Lean 4, theorem prover, proof, theorem, tactic, term, Mathlib, dependent types, type theory, LibraryLink, ProofObject, interactive proof, formal mathematics]
MainGuide: Documentation/English/Guides/LeanLink.nb
License: MIT
WolframVersion: 14.0+
Categories: [External Interfaces & Connections, Higher Mathematical Computation, Graphs & Networks]
Disclosures: [WLSystemSymbols]
Sources: ["Leonardo de Moura, Sebastian Ullrich, *The Lean 4 Theorem Prover and Programming Language*, CADE 28, 2021"]
SourceControlURL: https://github.com/WolframInstitute/LeanLink
RelatedResources: [MetamathImport]
Links: ["[Lean 4 (lean-lang.org)](https://lean-lang.org/)", "[leanprover/lean4 (GitHub)](https://github.com/leanprover/lean4)", "[Mathlib4 (GitHub)](https://github.com/leanprover-community/mathlib4)"]
---

## Details & Options

- LeanLink is a high-performance **native bridge** between the Wolfram Language and the [Lean 4](https://lean-lang.org/) theorem prover. It embeds the Lean runtime directly through a compiled [LibraryLink]() shim - there is no subprocess per call and no text-protocol round-trip for the core API.
- A loaded environment is a [LeanEnvironment](), a typed wrapper over <code>[Association]()[name -> [LeanTerm](), …]</code>. [LeanImport]() loads constants from a compiled Lean module (Mathlib included); [LeanImportString]() compiles a Lean source string on the fly.
- Every Lean expression is a symbolic tree built from a small set of CIC heads - [LeanConst](), [LeanApp](), [LeanForall](), [LeanLam](), [LeanBVar](), [LeanSort](), [LeanLitNat](), ... - each carrying box formatting so it displays in Lean-source notation.
- A [LeanTerm]() exposes `"Type"` / `"Term"` (expression trees), `"TypeForm"` / `"TermForm"` (pretty-printed source), `"Parameters"` (the unfolded binder chain), and `"ExprGraph"` / `"CallGraph"` (native [Graph]() visualizations).
- [LeanState]() and [LeanTactic]() drive **interactive tactic proofs** step by step; [ProofToLean]() transpiles a Wolfram [ProofObject]() into a checkable [LeanEnvironment](); [LeanCompile]() and [LeanToFunction]() lower a Lean definition to a [FunctionCompile]() function.
- The serialization backend is a compact binary (WXF) format, so goal states and expression trees cross the boundary without a parsing pass.

## Usage

The entry points are [LeanImport]() and [LeanImportString]() (load an environment) and [LeanExport]() / [LeanExportString]() (write Lean source back). [LeanTerm]() and [LeanEnvironment]() are the two computable wrappers; the `Parse*`-style CIC heads - [LeanConst](), [LeanApp](), [LeanForall](), [LeanLam](), [LeanLet](), [LeanBVar](), [LeanFVar](), [LeanSort](), [LeanLitNat](), [LeanLitStr](), [LeanProj]() - build expressions, with universe levels [LeanLevelZero](), [LeanLevelSucc](), [LeanLevelMax](). [LeanState](), [LeanTactic](), and [LeanGoal]() run interactive proofs; [ProofToLean]() transpiles a [ProofObject](); [LeanCompile](), [LeanToFunction]() compile to native code; [LeanExprGraph](), [LeanCallGraph](), [LeanListTheorems]() query a project out of process.

## Basic Examples

Load the bundled example environment:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]]
```

<!-- => LeanEnvironment summary box: 25 constants -->

---

How many constants, and of what kinds:

```wl
Length[env]
```

<!-- => 25 -->

```wl
Information[env, "Kinds"]
```

<!-- => <|"def" -> 6, "theorem" -> 18, "inductive" -> 1|> -->

---

A single constant is a [LeanTerm]() summary box:

```wl
env["id_proof"]
```

<!-- => LeanTerm summary box: Name id_proof, Kind theorem -->

Its type, pretty-printed as Lean source - the proposition it proves:

```wl
env["id_proof"]["TypeForm"]
```

<!-- => "∀ (P : Prop) (a : P), P" -->

And the proof term:

```wl
env["id_proof"]["TermForm"]
```

<!-- => "fun x hp => hp" -->

---

Every expression is a tree; `"ExprGraph"` draws it:

```wl
env["id_proof"]["ExprGraph"]
```

<!-- => Graph (6 vertices) of the type/term expression tree -->

`"CallGraph"` shows which constants a proof depends on:

```wl
env["or_comm_proof"]["CallGraph"]
```

<!-- => Graph: or_comm_proof -> {Or, Or.elim, Or.inl, Or.inr} -->

## Scope

Import from Mathlib by pointing `"ProjectDir"` at a built mathlib4 checkout (gated so the page still builds without one):

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[ DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
    mulComm = LeanImport["Mathlib.Algebra.Group.Basic",
        "ProjectDir" -> mathlibDir, "Filter" -> "mul_comm"];
    mulComm["mul_comm"]["TypeForm"],
    "Mathlib not built - run: lake exe cache get && lake build Mathlib.Algebra.Group.Basic"
]
```

<!-- => "∀ {G : Type u_1} [inst : CommMagma G] (a : G) (b : G), a * b = b * a" -->

---

The `"Parameters"` property unfolds a theorem's binder chain - explicit, implicit, and instance arguments - as a [Dataset]():

```wl
env["modus_ponens"]["Parameters"] // Dataset
```

<!-- => Dataset of 4 rows: P, Q (Prop, explicit), the hypotheses -->

## Applications

Open any theorem as a proof goal and step through it with tactics:

```wl
s0 = LeanState[env["id_proof"]]
```

<!-- => LeanState summary box, 1 goal: ⊢ ∀ (P : Prop), P → P -->

```wl
s1 = LeanTactic[{"intro P", "intro h", "exact h"}][s0];
s1["Complete"]
```

<!-- => True -->

---

Transpile a Wolfram [ProofObject]() into a checkable Lean environment:

```wl
leanEnv = ProofToLean[FindEquationalProof[a == c, {a == b, b == c}]];
Keys[leanEnv]
```

<!-- => {"Ax1", "Ax2", "Hyp1", "SL1", "FinalGoal"} -->

```wl
LeanState[leanEnv["FinalGoal"]]["Complete"]
```

<!-- => True -->

---

Lower a (non-dependent) Lean definition to native code via [FunctionCompile]():

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"];
cf = LeanCompile[addEnv["myAdd"]];
cf[3, 4]
```

<!-- => 7 -->

## Properties and Relations

[LeanImportString]() round-trips with [LeanExportString](): import a source string, query it, and export an environment back to Lean source:

```wl
imported = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
imported["myT"]["TypeForm"]
```

<!-- => "Nat.succ 0 = 1" -->

[ProofToLean]() complements [MetamathImport]() - both bring an external formal-proof corpus into the Wolfram Language; LeanLink targets Lean 4 / Mathlib and additionally drives the prover interactively.

## Possible Issues

- The native bridge needs the platform shim under `LeanLink/LibraryResources/` **and** the Lean toolchain it was built against (`leanprover/lean4:v4.29.0-rc6`) installed via [elan](https://github.com/leanprover/elan): the ~190 MB Lean runtime is not bundled, so on first use LeanLink links `libleanshared` from that toolchain next to the shim. Install it with `elan toolchain install leanprover/lean4:v4.29.0-rc6`. Mathlib import and the out-of-process graph functions ([LeanExprGraph](), [LeanCallGraph]()) additionally need `lake` on `PATH` and a **built** project - `LeanImport` of an unbuilt module returns an empty environment.
- [LeanCompile]()'s **dependent-type** path (Vector-sized signatures via `TypePi`) requires a forked Wolfram compiler; the non-dependent path works against the stock compiler.
- A type shown in isolation can print an unresolved bound variable as `#0` / `#1`; the full-theorem `"TypeForm"` resolves binder names.

## Neat Examples

The type of a Mathlib theorem, drawn as its expression tree (gated on a built checkout):

```wl
If[ DirectoryQ[FileNameJoin[{$HomeDirectory, "src", "mathlib4", ".lake", "build"}]],
    LeanImport["Mathlib.Logic.Basic",
        "ProjectDir" -> FileNameJoin[{$HomeDirectory, "src", "mathlib4"}],
        "Filter" -> "And.comm"]["And.comm"]["ExprGraph"],
    "Mathlib not built"
]
```

<!-- => Graph of the And.comm type tree (or a string if Mathlib is absent) -->

## Hero Image

The LeanLink banner - the spikey universal quantifier - loaded from the paclet's bundled asset.

```wl
Import[FileNameJoin[{PacletObject["Wolfram/LeanLink"]["Location"],
    "Assets", "leanlink_spikey_forall_1774968021189.png"}]]
```

## Author Notes

LeanLink's native bridge, kernel package, pretty-printer, and proof engine were written by Nik Murzin (Wolfram Institute). These documentation pages were drafted with Anthropic's [Claude](https://www.anthropic.com/claude) against the live paclet and reviewed by the author; AI-assisted authorship of the docs is disclosed here so a reader can weigh the source appropriately.
