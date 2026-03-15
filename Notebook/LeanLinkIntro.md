# LeanLink

Explore Lean 4 proof structures from Wolfram Language.

## Setup

```wolfram
PacletInstall["https://www.wolframcloud.com/obj/nikm/LeanLink.paclet", ForceVersionInstall -> True]
```

```wolfram
<< LeanLink`
```

## Quick Start

LeanLink ships with built-in examples: textbook proofs and dependent types.

### Import a standalone .lean file

```wolfram
exFile = PacletFind["LeanLink"][[1]]["AssetLocation", "Examples"]
```

```wolfram
env = LeanImport[exFile]
```

### Browse Constants

Internal names are filtered — only top-level theorems, definitions, and inductives show:

```wolfram
Keys[env]
```

### Typed Objects

Each value is a `LeanTerm` with its kind shown in a colored summary:

```wolfram
env["identity"]
```

```wolfram
env["Vec"]
```

```wolfram
env["Vec.head"]
```

### Property Access

```wolfram
env["identity"]["Kind"]
```

```wolfram
env["identity"]["Type"]
```

```wolfram
env["identity"]["Term"]
```

```wolfram
env["identity"]["Properties"]
```

### Expression Graph

Visualize the type as a tree — nodes are colored by head: blue for ∀, purple for λ, green for constants.

```wolfram
env["modus_ponens"]["ExprGraph"]
```

```wolfram
env["Vec.map"]["ExprGraph"]
```

### Call Graph

See which constants a proof depends on:

```wolfram
env["contrapositive"]["CallGraph"]
```

```wolfram
env["zero_add_proof"]["CallGraph"]
```

## Module Import

Import from a Lake project with compiled `.olean` files:

```wolfram
nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
```

```wolfram
env2 = LeanImport["LeanLink.Examples", "ProjectDir" -> nativeDir]
```

```wolfram
env2["LeanLink.Examples.modus_ponens"]["ExprGraph"]
```

## Low-Level API

Query individual constants without importing everything:

```wolfram
LeanExpr["LeanLink.Examples.modus_ponens", "Imports" -> {"LeanLink"}, "ProjectDir" -> nativeDir]
```

```wolfram
LeanValue["LeanLink.Examples.identity", "Imports" -> {"LeanLink"}, "ProjectDir" -> nativeDir, "Depth" -> 10]
```

## TM {2,2} Rule 445 — Successor Proof

The TuringMachineSearch project proves that the {2,2} Turing machine rule 445 computes the successor function:

```wolfram
projectDir = ParentDirectory[NotebookDirectory[], 2]
```

```wolfram
tm = LeanImport["OneSidedTM", "ProjectDir" -> projectDir, "Filter" -> "rule445"]
```

```wolfram
tm["OneSidedTM.rule445_computesSucc"]["ExprGraph"]
```

```wolfram
tm["OneSidedTM.rule445_computesSucc"]["CallGraph"]
```
