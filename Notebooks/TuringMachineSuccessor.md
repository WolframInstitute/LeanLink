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

A one-sided Turing machine reads a binary-encoded natural number on its tape (LSB at position 0), executes transitions, and halts when the head moves past position 0 to the left. We ask: which TMs compute the successor function? And can we prove it for ALL inputs?

## Part 1: Formalizing the Machine

We import the foundational definitions. `LeanImportString` compiles Lean 4 source directly and returns a `LeanEnvironment` of inspectable terms.

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
Keys[defsEnv]
```

```wolfram
defsEnv["TM"]["TypeForm"]
```

## Part 2: The Successor Predicate

`ComputesSucc` says: for every n >= 1 there is enough fuel for the TM to halt with output n + 1.

```wolfram
succEnv = LeanImportString["
def ComputesSucc (run : Nat -> Nat -> Option Nat) : Prop :=
  forall n : Nat, n >= 1 -> Exists fun fuel => run n fuel = some (n + 1)
"]
```

```wolfram
succEnv["ComputesSucc"]["TypeForm"]
```

```wolfram
succEnv["ComputesSucc"]["Type"]
```

## Part 3: Rule 445 -- The Machine

Rule 445 is the canonical (2,2) successor-computing TM. Its transition table:

```wolfram
TuringMachineRuleCases[{445, 2, 2}]
```

The algorithm: carry phase scans left flipping 1 -> 0. On first 0: absorb (write 1), then scan back to position 0.

```wolfram
Grid[{{OneSidedTuringMachinePlot[{445, 2, 2}, 1, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 3, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 7, 20, ImageSize -> 120, "LabelInput" -> True], OneSidedTuringMachinePlot[{445, 2, 2}, 15, 40, ImageSize -> 120, "LabelInput" -> True]}}, Spacings -> 2]
```

## Part 4: Importing the Full Proof from GitHub

Instead of inlining code, we import the complete proof directly from GitHub. `LeanImport` automatically downloads the file and all its dependencies, compiles the project with `lake build`, and loads every proven theorem into a `LeanEnvironment`:

```wolfram
plusOneEnv = LeanImport["https://github.com/WolframInstitute/TuringMachine/blob/main/Proofs/OneSidedTM/PlusOne.lean"]
```

```wolfram
Keys[plusOneEnv]
```

### Machine-Checked Spot Checks via `native_decide`

The simplest proof strategy: Lean's kernel verifies the computation directly for specific inputs.

```wolfram
plusOneEnv["rule445_succ_7"]["TypeForm"]
```

```wolfram
plusOneEnv["rule445_succ_255"]["TypeForm"]
```

Bulk verification -- all inputs 1 through 65535 checked in a single `native_decide`:

```wolfram
plusOneEnv["rule445_succ_bulk"]["TypeForm"]
```

### The Universal Proof: `rule445_computesSucc`

The crown jewel: a proof that Rule 445 computes successor for ALL inputs, by structural induction on the binary representation. No finite enumeration -- true for every natural number:

```wolfram
plusOneEnv["rule445_computesSucc"]["TypeForm"]
```

```wolfram
plusOneEnv["rule445_computesSucc"]["Type"]
```

### Inspecting the Proof Term

The proof breaks execution into three phases: carry (flip 1->0 scanning left), absorb (write 1 at MSB), and scanback (verify tape). The `ExprGraph` shows the proof term's dependency structure:

```wolfram
plusOneEnv["rule445_computesSucc"]["ExprGraph"]
```

## Part 5: All 17 Rules in the (2,2) Space

17 rules compute binary successor. They partition into classes by algorithm shape:

```wolfram
successorRules22 = OneSidedTuringMachineFind[{Range[2, 21]}, 200, {2, 2}]
```

```wolfram
Length[successorRules22]
```

Visual comparison across classes:

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{445, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 445 (Class A)", Bold, 11], Top], Labeled[OneSidedTuringMachinePlot[{453, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 453 (Class B)", Bold, 11], Top], Labeled[OneSidedTuringMachinePlot[{1512, 2, 2}, 7, 20, ImageSize -> 180, "LabelInput" -> True], Style["Rule 1512 (Class C)", Bold, 11], Top]}}, Spacings -> 2]
```

## Part 6: Class C -- Carry + Absorb + Clear

Class C machines skip past trailing 1-bits, absorb at the first 0, then clear on return. All 8 rules 1512-1519 are Class C:

```wolfram
classCEnv = LeanImport["https://github.com/WolframInstitute/TuringMachine/blob/main/Proofs/OneSidedTM/ClassC.lean"]
```

The structural predicate `IsClassC` captures the algorithm pattern:

```wolfram
classCEnv["IsClassC"]["TypeForm"]
```

```wolfram
classCEnv["IsClassC"]["Type"]
```

The main theorem: ANY TM matching this pattern computes successor:

```wolfram
classCEnv["classC_computesSucc"]["TypeForm"]
```

```wolfram
classCEnv["classC_computesSucc"]["Type"]
```

## Part 7: Class B -- Bounce-Back Scanback

Class B machines use a different return strategy: bouncing between states while clearing bits.

```wolfram
classBEnv = LeanImport["https://github.com/WolframInstitute/TuringMachine/blob/main/Proofs/OneSidedTM/ClassB.lean"]
```

```wolfram
classBEnv["IsClassB"]["TypeForm"]
```

```wolfram
classBEnv["classB_computesSucc"]["TypeForm"]
```

## Part 8: 3-State Proofs -- Extended Scan Variants

The 3-state space introduces toggle and drop clearback variants. `ClassSX` proves ALL three clearback strategies compute successor:

```wolfram
classSXEnv = LeanImport["https://github.com/WolframInstitute/TuringMachine/blob/main/Proofs/OneSidedTM/ClassSX.lean"]
```

```wolfram
Keys[classSXEnv]
```

Self-loop, toggle, and drop -- three different clearback strategies, one proof framework:

```wolfram
classSXEnv["classSX_self_computes"]["TypeForm"]
```

```wolfram
classSXEnv["classSX_toggle_computes"]["TypeForm"]
```

```wolfram
classSXEnv["classSX_drop_computes"]["TypeForm"]
```

### 3-State Machine Visualization

Rule 146514 is a genuine 3-state successor machine. 2352 rules share this step profile.

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{445, 2, 2}, 31, 50, ImageSize -> 200, "LabelInput" -> True], Style["Rule 445 (2-state)", Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{146514, 3, 2}, 31, 200, ImageSize -> 200, "LabelInput" -> True], Style["Rule 146514 (3-state)", Bold, 12], Top]}}, Spacings -> 3]
```

## Part 9: The Near-Miss -- Proving Incorrectness

Rule 156830 correctly computes successor for inputs 1 through 6, then fails at n = 7 (outputs 9 instead of 8):

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 6, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 6 (correct)", Darker[Green], Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 7, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 7 (FAILS: outputs 9)", Red, Bold, 12], Top]}}, Spacings -> 3]
```

## Summary: Proof Architecture

The Lean 4 proof architecture (in `OneSidedTM/`) proceeds in layers:

- `native_decide` bulk checks: verify correctness for all inputs in a finite range (e.g. 1..65535)
- Structural induction via `sim_eval`: proves correctness for ALL inputs by decomposing TM execution into carry, absorb, and walkback phases
- Class-level generalization: any TM matching the carry+absorb+walkback pattern computes successor -- individual rules are cheap instances
- Extended variants (toggle, drop, delegation): cover the full 3-state search space

All proofs compile with zero `sorry`s on Lean v4.29.0-rc6. Source: [WolframInstitute/TuringMachine/Proofs](https://github.com/WolframInstitute/TuringMachine/tree/main/Proofs)
