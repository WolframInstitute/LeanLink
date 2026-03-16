# LeanLink — Interactive Lean from Wolfram Language

## Setup

```wolfram
PacletDirectoryLoad[NotebookDirectory[] // ParentDirectory];
Get["LeanLink`"];
nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
```

## Importing a Lean Environment

```wolfram
env = LeanImport["LeanLink.Examples",
  "ProjectDir" -> nativeDir,
  "Imports" -> {"LeanLink"},
  "Filter" -> "Examples"]
```

```wolfram
Keys[env]
```

## Inspecting Types and Terms

```wolfram
env["LeanLink.Examples.identity"]["TypeForm"]
```

```wolfram
env["LeanLink.Examples.identity"]["Type"]
```

```wolfram
env["LeanLink.Examples.Vec.head"]["TypeForm", 1]
```

## Expression Graphs

```wolfram
env["LeanLink.Examples.modus_ponens"]["ExprGraph"]
```

## Constructing Expressions

Build a Lean expression and bind it to an environment for type-checking:

```wolfram
LeanTerm[LeanApp[LeanConst["Nat.succ", {}], LeanLitNat[42]], env]
```

```wolfram
%["TypeForm"]
```

## Interactive Tactic Proofs

### Identity: $\forall P : \text{Prop},\; P \to P$

```wolfram
s0 = LeanState[env["LeanLink.Examples.identity"]]
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
s0 = LeanState[env["LeanLink.Examples.modus_ponens"]]
```

```wolfram
LeanTactic[{"intro P Q hP hPQ", "exact hPQ hP"}][s0]
```

### And Commutativity: $P \land Q \to Q \land P$

```wolfram
s0 = LeanState[env["LeanLink.Examples.and_comm"]]
```

```wolfram
LeanTactic[{"intro P Q h", "exact And.intro h.2 h.1"}][s0]
```

### Accessing Goal Properties

```wolfram
s0 = LeanState[env["LeanLink.Examples.identity"]];
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
