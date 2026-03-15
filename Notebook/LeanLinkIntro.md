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

LeanLink ships with a built-in `LeanLink.Examples` module containing textbook proofs and dependent types.

Point to the native build directory:

```wolfram
nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
```

### Import a Module

```wolfram
env = LeanImport["LeanLink", "ProjectDir" -> nativeDir, "Filter" -> "LeanLink.Examples"]
```

### Browse Constants

Keys of the returned Association are fully qualified names:

```wolfram
Keys[env]
```

### Typed Objects

Each value is a `LeanTerm` with its kind (theorem, def, inductive, axiom, ...) shown in the summary:

```wolfram
env["LeanLink.Examples.identity"]
```

```wolfram
env["LeanLink.Examples.Vec"]
```

```wolfram
env["LeanLink.Examples.Vec.head"]
```

### Property Access

```wolfram
env["LeanLink.Examples.identity"]["Kind"]
```

```wolfram
env["LeanLink.Examples.identity"]["Type"]
```

```wolfram
env["LeanLink.Examples.identity"]["Term"]
```

```wolfram
env["LeanLink.Examples.identity"]["Properties"]
```

### Expression Graph

Visualize the type as a tree. Each node is color-coded by its expression head: blue for `∀`, purple for `λ`, green for constants.

```wolfram
env["LeanLink.Examples.modus_ponens"]["ExprGraph"]
```

```wolfram
env["LeanLink.Examples.Vec.map"]["ExprGraph"]
```

### Call Graph

See which constants a proof references:

```wolfram
env["LeanLink.Examples.contrapositive"]["CallGraph"]
```

```wolfram
env["LeanLink.Examples.zero_add_proof"]["CallGraph"]
```

## Low-Level API

For fine-grained queries, use the raw functions directly:

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

Import the PlusOne module:

```wolfram
tm = LeanImport["OneSidedTM", "ProjectDir" -> projectDir, "Filter" -> "rule445"]
```

Expression graph of a successor proof:

```wolfram
tm["OneSidedTM.rule445_computesSucc"]["ExprGraph"]
```

Call graph showing proof dependencies:

```wolfram
tm["OneSidedTM.rule445_computesSucc"]["CallGraph"]
```
