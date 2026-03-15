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

LeanLink provides three functions:

- `LeanExprGraph[file, name]` — expression tree of a proof term
- `LeanCallGraph[file, name]` — dependency graph of theorem references
- `LeanListTheorems[file]` — enumerate all definitions and theorems

All accept a raw `.lean` file as the first argument. No lake project required.

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


## TM {2,2} Rule 445 — Successor Proof

The TuringMachineSearch project proves that the {2,2} Turing machine rule 445 computes the successor function:

```wolfram
projectDir = "Proofs";
```

List theorems from the PlusOne module:

```wolfram
LeanListTheorems["Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir, "Filter" -> "rule445"]
```

Expression graph of a successor proof:

```wolfram
LeanExprGraph["OneSidedTM.rule445_succ_1", "Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir]
```

Call graph showing proof dependencies of the main theorem:

```wolfram
LeanCallGraph["OneSidedTM.rule445_computesSucc", "Imports" -> {"OneSidedTM.PlusOne"}, "ProjectDir" -> projectDir]
```
