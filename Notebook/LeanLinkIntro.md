# LeanLink — Interactive Lean from Wolfram Language

## Setup

Load the paclet and point it at the Lean project:

```wolfram
PacletDirectoryLoad[NotebookDirectory[] // ParentDirectory];
Needs["LeanLink`"];
nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
```

## Importing a Lean Environment

Import constants from a Lean module. This is lazy — only names and kinds are loaded upfront:

```wolfram
env = LeanImport["LeanLink.Examples",
  "ProjectDir" -> nativeDir,
  "Imports" -> {"LeanLink"},
  "Filter" -> "Examples"]
```

List the available constants:

```wolfram
Keys[env]
```

## Inspecting Types and Terms

Each entry is a `LeanTerm`. Access its type (as an expression tree) or as a pretty-printed string:

```wolfram
env["LeanLink.Examples.identity"]["TypeForm"]
```

```wolfram
env["LeanLink.Examples.identity"]["Type"]
```

```wolfram
env["LeanLink.Examples.identity"]["TermForm"]
```

View the type with definitions unfolded (level 1 = unfold each definition once):

```wolfram
env["LeanLink.Examples.Vec.head"]["TypeForm", 1]
```

## Expression Graphs

Visualize the structure of a definition as a graph:

```wolfram
env["LeanLink.Examples.modus_ponens"]["ExprGraph"]
```

## Constructing Expressions & Type-Checking

Build Lean expressions from WL heads and type-check them against the environment:

```wolfram
expr = LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[42]];
LeanTypeCheck[expr, env]
```

```wolfram
LeanTypeCheck[LeanConst["LeanLink.Examples.identity", {}], env]
```

## Interactive Tactic Proofs

Open a proof goal for a theorem and step through it interactively:

### Example 1: Identity (∀ P : Prop, P → P)

```wolfram
s0 = LeanOpenGoal[env["LeanLink.Examples.identity"]];
FormatLeanState[s0]
```

Introduce the proposition P:

```wolfram
s1 = LeanApplyTactic[s0["stateId"], "intro P"];
FormatLeanState[s1]
```

Introduce the hypothesis h : P:

```wolfram
s2 = LeanApplyTactic[s1["stateId"], "intro h"];
FormatLeanState[s2]
```

Close the goal — h is exactly what we need:

```wolfram
s3 = LeanApplyTactic[s2["stateId"], "exact h"];
FormatLeanState[s3]
```

### Example 2: Modus Ponens (P → (P → Q) → Q)

```wolfram
s0 = LeanOpenGoal[env["LeanLink.Examples.modus_ponens"]];
FormatLeanState[s0]
```

```wolfram
s1 = LeanApplyTactic[s0["stateId"], "intro P Q hP hPQ"];
FormatLeanState[s1]
```

```wolfram
s2 = LeanApplyTactic[s1["stateId"], "exact hPQ hP"];
FormatLeanState[s2]
```

### Example 3: Contrapositive ((P → Q) → ¬Q → ¬P)

```wolfram
s0 = LeanOpenGoal[env["LeanLink.Examples.contrapositive"]];
FormatLeanState[s0]
```

```wolfram
s1 = LeanApplyTactic[s0["stateId"], "intro P Q hPQ hNQ hP"];
FormatLeanState[s1]
```

```wolfram
s2 = LeanApplyTactic[s1["stateId"], "exact hNQ (hPQ hP)"];
FormatLeanState[s2]
```

### Example 4: Piping Tactics

Apply multiple tactics in one call:

```wolfram
s0 = LeanOpenGoal[env["LeanLink.Examples.and_comm"]];
FormatLeanState[s0]
```

```wolfram
sf = LeanApplyTactic[s0["stateId"], {"intro h", "exact \[LeftAngleBracket]h.2, h.1\[RightAngleBracket]"}];
FormatLeanState[sf]
```
