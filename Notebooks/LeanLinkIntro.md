# LeanLink — Interactive Lean from Wolfram Language

## Setup

```wolfram
(*PacletDirectoryLoad[NotebookDirectory[] // ParentDirectory];*)
PacletInstall["https://www.wolframcloud.com/obj/nikm/LeanLink.paclet", ForceVersionInstall -> True];
Get["LeanLink`"];
```

## Importing a Lean Environment

Load the bundled Examples file:

```wolfram
env = LeanImportString[
  Import[PacletObject["LeanLink"]["AssetLocation", "Examples"], "Text"]]
```

```wolfram
Keys[env]
```

## Inspecting Types and Terms

```wolfram
env["id_proof"]["TypeForm"]
```

```wolfram
env["id_proof"]["Type"]
```

```wolfram
env["Vec.head"]["TypeForm", 1]
```

## Expression Graphs

```wolfram
env["modus_ponens"]["ExprGraph"]
```

## Constructing Expressions

Build a Lean expression and bind it to an environment for type-checking:

```wolfram
LeanTerm[LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]], env]
```

```wolfram
%["TypeForm"]
```

Type-check a forall expression:

```wolfram
LeanTerm[LeanForall["n", LeanConst["Nat"], LeanConst["Nat"], "default"], env]["Type"]
```

## Interactive Tactic Proofs

### Identity: $\forall P : \text{Prop},\; P \to P$

```wolfram
s0 = LeanState[env["id_proof"]]
```

```wolfram
s1 = LeanTactic["intro P"][s0]
```

```wolfram
s2 = LeanTactic["intro h"][s1]
```

```wolfram
s3 = LeanTactic["exact h"][s2]
```

### Modus Ponens: $P \to (P \to Q) \to Q$

```wolfram
s0 = LeanState[env["modus_ponens"]]
```

```wolfram
LeanTactic[{"intro P Q hP hPQ", "exact hPQ hP"}][s0]
```

### Contrapositive: $(P \to Q) \to (\neg Q \to \neg P)$

```wolfram
s0 = LeanState[env["contrapositive"]]
```

```wolfram
LeanTactic[{"intro P Q hPQ hnQ hP", "apply hnQ", "exact hPQ hP"}][s0]
```

### And Commutativity: $P \land Q \to Q \land P$

```wolfram
s0 = LeanState[env["and_comm_proof"]]
```

```wolfram
s1 = LeanTactic["intro P Q h"][s0]
```

```wolfram
s2 = LeanTactic["constructor"][s1]
```

### Accessing Goal Properties

```wolfram
s0 = LeanState[env["id_proof"]];
s0["Goals"]
```

```wolfram
s0["Goals"][[1]]["Target"]
```

```wolfram
s0["Goals"][[1]]["Context"]
```

```wolfram
s0["Complete"]
```

## LeanEnvironment

`LeanImportString` returns a `LeanEnvironment` — a typed wrapper around `<|name → LeanTerm, ...|>`:

```wolfram
Head[env]
```

```wolfram
Length[env]
```

```wolfram
env["id_proof"]
```

```wolfram
Information[env, "Kinds"]
```

## Exporting to Source

### Single term

```wolfram
LeanExportString[env["id_proof"]]
```

### Full environment to file

```wolfram
LeanExport[FileNameJoin[{$TemporaryDirectory, "out.lean"}], env]
```

## Importing from Source String

```wolfram
imported = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

```wolfram
imported["myT"]["TypeForm"]
```

## ProofToLean — ProofObject to Lean

Transpile a Wolfram `ProofObject` into a `LeanEnvironment` with expression tree types and structured tactics:

```wolfram
proof = FindEquationalProof[a == c, {a == b, b == c}];
leanEnv = ProofToLean[proof]
```

### Inspecting the result

```wolfram
Keys[leanEnv]
```

```wolfram
leanEnv["FinalGoal"]["Type"]
```

```wolfram
leanEnv["FinalGoal"]["TypeForm"]
```

### Generated Lean source

```wolfram
LeanExportString[leanEnv]
```

### Roundtrip: ProofObject → LeanTerm → Source → LeanImportString

```wolfram
src = LeanExportString[leanEnv];
roundtrip = LeanImportString[src];
Keys[roundtrip]
```

### Auto-completing proofs with LeanState

```wolfram
goal = leanEnv["FinalGoal"];
state = LeanState@goal;
state["Complete"]
```

## Importing from Mathlib

LeanLink can import theorems from any Lean project. Point `"ProjectDir"` at a mathlib4 checkout where `lake exe cache get && lake build Mathlib.Tactic.Ring` has been run:

```wolfram
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
If[DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]],
  mathEnv = LeanImport["Mathlib.Tactic.Ring",
    "ProjectDir" -> mathlibDir,
    "Filter" -> "Ring"];
  Length[mathEnv],
  "Mathlib not built — run in mathlib4/: lake exe cache get && lake build Mathlib.Tactic.Ring"]
```

## Structured Tactics

Tactics are symbolic objects with Lean-native names:

```wolfram
LeanTactic["exact", LeanConst["h"]]
```

```wolfram
LeanTactic[{
  LeanTactic["intro", {"P", "h"}],
  LeanTactic["exact", LeanConst["h"]]
}]
```

Apply structured tactics to proof states:

```wolfram
s0 = LeanState[env["id_proof"]];
s1 = LeanTactic["intro", {"P"}][s0];
s2 = LeanTactic["intro", {"h"}][s1];
s3 = LeanTactic["exact", LeanConst["h"]][s2];
s3["Complete"]
```
