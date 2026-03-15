# LeanLink

Visualize Lean 4 proof structures as Wolfram Language graphs.

## Installation

```wolfram
PacletInstall["https://www.wolframcloud.com/obj/nikm/LeanLink.paclet", ForceVersionInstall -> True]
```

```wolfram
<< LeanLink`
```

## Functions

LeanLink provides two layers of API:

**Native API** (LibraryLink, fast):

- `LeanImport[opts]` — one-shot import returning an Association of typed objects
- `LeanExpr[name, opts]` — type of a constant as a symbolic expression tree
- `LeanValue[name, opts]` — proof or definition body
- `LeanConstantInfo[name, opts]` — full constant info
- `LeanListConstants[opts]` — list all constants

**Subprocess API** (invokes `lean` CLI):

- `LeanExprGraph[name, opts]` — expression tree graph
- `LeanCallGraph[name, opts]` — dependency graph
- `LeanListTheorems[opts]` — enumerate theorems and definitions

## Quick Start

LeanLink ships with a bundled `Examples.lean`:

```wolfram
exFile = PacletObject["LeanLink"]["AssetLocation", "Examples"];
```

### List Theorems

```wolfram
LeanListTheorems[exFile]
```

```wolfram
LeanListTheorems[exFile, "Filter" -> "add"]
```

### Expression Graph

```wolfram
LeanExprGraph[exFile, "modus_ponens"]
```

```wolfram
LeanExprGraph[exFile, "Vec.map"]
```

### Call Graph

```wolfram
LeanCallGraph[exFile, "zero_add_proof"]
```

## Native API — LeanImport

`LeanImport` loads a Lean module via LibraryLink and returns an Association of typed objects. Each object has a kind-specific head (`LeanTheorem`, `LeanDefinition`, `LeanAxiom`, `LeanInductive`, `LeanConstructor`, `LeanRecursor`) with formatted output and property access.

Set up the project directory (the directory containing `lakefile.lean` and `.lake/build/lib/`):

```wolfram
nativeDir = FileNameJoin[{PacletObject["LeanLink"]["Location"], "Native"}];
```

### Import a module

Import all constants from `LeanLink.Examples`:

```wolfram
env = LeanImport["LeanLink", "ProjectDir" -> nativeDir, "Filter" -> "LeanLink.Examples"]
```

The result is an Association where keys are fully qualified names and values are typed Lean objects:

```wolfram
Keys[env]
```

### Typed Objects

Each value has a kind-specific head:

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

Every object supports property access:

```wolfram
env["LeanLink.Examples.identity"]["Name"]
```

```wolfram
env["LeanLink.Examples.identity"]["Kind"]
```

```wolfram
env["LeanLink.Examples.identity"]["Type"]
```

```wolfram
env["LeanLink.Examples.identity"]["Value"]
```

List all available properties:

```wolfram
env["LeanLink.Examples.identity"]["Properties"]
```

### Native Type Queries

Get just the type of a constant:

```wolfram
LeanExpr["LeanLink.Examples.modus_ponens", "Imports" -> {"LeanLink"}, "ProjectDir" -> nativeDir]
```

Get the proof term:

```wolfram
LeanValue["LeanLink.Examples.contrapositive", "Imports" -> {"LeanLink"}, "ProjectDir" -> nativeDir, "Depth" -> 10]
```

## TM {2,2} Rule 445 — Successor Proof

The TuringMachineSearch project proves that the {2,2} Turing machine rule 445 computes the successor function:

```wolfram
projectDir = FileNameJoin[NotebookDirectory[], "Proofs"];
```

List theorems from the PlusOne module:

```wolfram
LeanListTheorems["Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir, "Filter" -> "rule445"]
```

Expression graph of a successor proof:

```wolfram
LeanExprGraph["OneSidedTM.rule445_computesSucc", 
 "Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir, 
 "Depth" -> 5]
```

Call graph showing proof dependencies of the main theorem:

```wolfram
LeanCallGraph["OneSidedTM.rule445_computesSucc", 
 "Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir, 
 "Depth" -> 2]
```
