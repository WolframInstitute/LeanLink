# Proving Turing Machines Compute Successor

## Setup

```wolfram
PacletInstall["https://www.wolframcloud.com/obj/nikm/LeanLink.paclet", ForceVersionInstall -> True];
PacletInstall["https://www.wolframcloud.com/obj/nikm/TuringMachine.paclet", ForceVersionInstall -> True];
```

```wolfram
Get["LeanLink`"];
Get["WolframInstitute`TuringMachine`"];
```

```wolfram
proofDir = FileNameJoin[{DirectoryName[PacletObject["WolframInstitute/TuringMachine"]["Location"]], "Proofs"}];
p = "OneSidedTM.";
leanImport[mod_] := LeanImport[mod, "ProjectDir" -> proofDir, "Filter" -> "OneSidedTM"]
```

A one-sided Turing machine reads a binary-encoded natural number on its tape (LSB at position 0), executes transitions, and halts when the head moves past position 0 to the left. We ask: which TMs compute the successor function? And can we prove it for ALL inputs?

## Part 1: Formalizing the Machine

```wolfram
defsEnv = LeanImportString["
inductive Dir where | L | R deriving Repr, DecidableEq, BEq

structure Rule where
  nextState : Nat
  write     : Nat
  dir       : Dir
  deriving Repr, DecidableEq, BEq

structure TM where
  numStates  : Nat
  numSymbols : Nat
  transition : Nat -> Nat -> Rule
"]
```

```wolfram
defsEnv["TM"]["TypeForm"]
```

## Part 2: The Successor Predicate

`ComputesSucc` says: for every n >= 1 there exists enough fuel for the TM to halt with output n + 1.

```wolfram
succEnv = LeanImportString["
def ComputesSucc (run : Nat -> Nat -> Option Nat) : Prop :=
  forall n : Nat, n >= 1 -> Exists fun fuel => run n fuel = some (n + 1)
"]
```

```wolfram
succEnv["ComputesSucc"]["TypeForm"]
```

## Part 3: Rule 445 -- The Machine

Rule 445 is the canonical (2,2) successor-computing TM.

```wolfram
Grid[{{OneSidedTuringMachinePlot[{445, 2, 2}, 1, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 3, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 7, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 15, 40, ImageSize -> 120, "LabelInput" -> True]}}, Spacings -> 2]
```

## Part 4: The Universal Proof

```wolfram
plusOneEnv = leanImport["OneSidedTM.PlusOne"]
```

### Machine-Checked Spot Checks via `native_decide`

```wolfram
plusOneEnv[p <> "rule445_succ_7"]["TypeForm"]
```

### `rule445_computesSucc` -- Correctness for ALL inputs

Structural induction on the binary representation. No finite enumeration -- true for every natural number:

```wolfram
plusOneEnv[p <> "rule445_computesSucc"]["TypeForm"]
```

```wolfram
plusOneEnv[p <> "rule445_computesSucc"]["ExprGraph"]
```

## Part 5: All (2,2) Successor Rules by Class

17 rules compute binary successor in the (2,2) space, partitioned into 3 classes:

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{445, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 445 (Class A)", Bold, 11], Top], Labeled[OneSidedTuringMachinePlot[{453, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 453 (Class B)", Bold, 11], Top], Labeled[OneSidedTuringMachinePlot[{1512, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 1512 (Class C)", Bold, 11], Top]}}, Spacings -> 2]
```

### Class B: Bounce-Back Scanback (8 rules)

```wolfram
allEnv = leanImport["OneSidedTM.AllPlusOne"]
```

```wolfram
allEnv[p <> "classB_computesSucc"]["TypeForm"]
```

```wolfram
allEnv[p <> "classB_computesSucc"]["ExprGraph"]
```

### Class C: Skip + Absorb + Clear-on-Return (8 rules)

```wolfram
allEnv[p <> "classC_computesSucc"]["TypeForm"]
```

```wolfram
allEnv[p <> "classC_computesSucc"]["ExprGraph"]
```

## Part 6: 3-State (3,2) Proof Classes

### ThreeState: Rule 146514

```wolfram
threeEnv = leanImport["OneSidedTM.ThreeState"]
```

```wolfram
threeEnv[p <> "rule146514_computesSucc"]["TypeForm"]
```

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{445, 2, 2}, 31, 50, ImageSize -> 200, "LabelInput" -> True], Style["Rule 445 (2-state)", Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{146514, 3, 2}, 31, 200, ImageSize -> 200, "LabelInput" -> True], Style["Rule 146514 (3-state)", Bold, 12], Top]}}, Spacings -> 3]
```

```wolfram
threeEnv[p <> "rule146514_computesSucc"]["ExprGraph"]
```

### Class S: Self-Loop Clear

```wolfram
classSEnv = leanImport["OneSidedTM.ClassS"]
```

```wolfram
classSEnv[p <> "classS_computesSucc"]["TypeForm"]
```

```wolfram
classSEnv[p <> "classS_computesSucc"]["ExprGraph"]
```

### Class SX: Toggle + Drop + Self-Loop Variants

```wolfram
classSXEnv = leanImport["OneSidedTM.ClassSX"]
```

```wolfram
{classSXEnv[p <> "classSX_self_computes"]["TypeForm"], classSXEnv[p <> "classSX_toggle_computes"]["TypeForm"], classSXEnv[p <> "classSX_drop_computes"]["TypeForm"]}
```

```wolfram
classSXEnv[p <> "classSX_toggle_computes"]["ExprGraph"]
```

### Class SB: Bouncing Clearback

```wolfram
classSBEnv = leanImport["OneSidedTM.ClassSB"]
```

```wolfram
classSBEnv[p <> "classSB_computesSucc"]["TypeForm"]
```

```wolfram
classSBEnv[p <> "classSB_computesSucc"]["ExprGraph"]
```

### Class D: Delegated Scan (DW + DS)

```wolfram
classDEnv = leanImport["OneSidedTM.ClassD"]
```

```wolfram
{classDEnv[p <> "classDW_computesSucc"]["TypeForm"], classDEnv[p <> "classDS_computesSucc"]["TypeForm"]}
```

```wolfram
classDEnv[p <> "classDW_computesSucc"]["ExprGraph"]
```

### Class W: Walk Variants

```wolfram
classWEnv = leanImport["OneSidedTM.ClassW"]
```

```wolfram
{classWEnv[p <> "exampleW8Self_computesSucc"]["TypeForm"], classWEnv[p <> "exampleW17Toggle_computesSucc"]["TypeForm"]}
```

```wolfram
classWEnv[p <> "exampleW8Self_computesSucc"]["ExprGraph"]
```

## Part 7: The Near-Miss -- Proving Incorrectness

Rule 156830 correctly computes successor for inputs 1 through 6, then fails at n = 7:

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 6, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 6 (correct)", Darker[Green], Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 7, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 7 (FAILS: outputs 9)", Red, Bold, 12], Top]}}, Spacings -> 3]
```

## Summary: Proof Architecture

| Layer | Strategy | Coverage |
|-------|----------|----------|
| `native_decide` | Kernel-verified computation | Finite range (1..65535) |
| `sim_eval` induction | Structural binary induction | ALL inputs (∀ n ≥ 1) |
| Class predicates | `IsClassB`, `IsClassC`, `IsClassS`, ... | Algorithm families |
| Extended variants | Toggle, drop, delegation | Full 3-state space |

### (2,2) Classes

| Class | Algorithm | Rules | Proof |
|-------|-----------|-------|-------|
| A | Carry + absorb + scanback | 445 | `rule445_computesSucc` |
| B | Bounce-back scanback | 453, 461, 469, 477, 485, 493, 501, 509 | `classB_computesSucc` |
| C | Skip + absorb + clear | 1512-1519 | `classC_computesSucc` |

### (3,2) Classes

| Class | Algorithm | Example Rules | Proof |
|-------|-----------|---------------|-------|
| ThreeState | Direct 3-state | 146514 | `rule146514_computesSucc` |
| S | Self-loop clear | 651613, 727741 | `classS_computesSucc` |
| SB | Bouncing clear | — | `classSB_computesSucc` |
| SX | Toggle/drop/self variants | 658573, 741517 | `classSX_*_computes` |
| D | Delegated scan (DW/DS) | — | `classDW/DS_computesSucc` |
| W | Walk variants | 145872, 146453 | `exampleW*_computesSucc` |

All proofs compile with zero `sorry`s on Lean v4.29.0-rc6. Source: [WolframInstitute/TuringMachine/Proofs](https://github.com/WolframInstitute/TuringMachine/tree/main/Proofs)
