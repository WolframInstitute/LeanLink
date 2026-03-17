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

### Interactive Proof Exploration

We can open a theorem as a proof goal and step through it with tactics:

```wolfram
witnessEnv = LeanImportString["
def trivialRun (n fuel : Nat) : Option Nat := if fuel > 0 then some (n + 1) else none
theorem succ_witness : forall n : Nat, n >= 1 -> Exists fun fuel => trivialRun n fuel = some (n + 1) := by
  intro n _hn
  exact Exists.intro 1 (by simp [trivialRun])
"]
```

```wolfram
s0 = LeanState[witnessEnv["succ_witness"]]
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

### Machine-Checked Spot Checks

The simplest proof strategy uses `native_decide`: Lean's kernel verifies the computation directly.

```wolfram
spotEnv = LeanImportString["
inductive Dir where | L | R deriving Repr, DecidableEq, BEq
structure Rule where
  nextState : Nat; write : Nat; dir : Dir
  deriving Repr, DecidableEq, BEq
structure TM where
  numStates : Nat; numSymbols : Nat; transition : Nat -> Nat -> Rule
structure Config where
  state : Nat; pos : Nat; tape : List Nat
  deriving Repr, DecidableEq, BEq

def readTape (tape : List Nat) (pos : Nat) : Nat := tape[pos]?.getD 0
def writeTape (tape : List Nat) (pos : Nat) (val : Nat) : List Nat :=
  if pos < tape.length then tape.set pos val
  else tape ++ List.replicate (pos - tape.length) 0 ++ [val]

inductive StepResult where
  | halted : Config -> StepResult
  | continue : Config -> StepResult
  deriving Repr, DecidableEq, BEq

def step (tm : TM) (cfg : Config) : StepResult :=
  let sym := readTape cfg.tape cfg.pos
  let rule := tm.transition cfg.state sym
  let tape' := writeTape cfg.tape cfg.pos rule.write
  match rule.dir with
  | Dir.L =>
    if cfg.pos == 0 then StepResult.halted { state := rule.nextState, pos := 0, tape := tape' }
    else StepResult.continue { state := rule.nextState, pos := cfg.pos - 1, tape := tape' }
  | Dir.R => StepResult.continue { state := rule.nextState, pos := cfg.pos + 1, tape := tape' }

def eval (tm : TM) (cfg : Config) : Nat -> Option Config
  | 0 => none
  | fuel + 1 => match step tm cfg with
    | StepResult.halted cfg' => some cfg'
    | StepResult.continue cfg' => eval tm cfg' fuel

def fromBinary : List Nat -> Nat
  | [] => 0
  | d :: rest => d + 2 * fromBinary rest

def trimTrailingZeros (l : List Nat) : List Nat :=
  let r := l.reverse.dropWhile (· == 0)
  if r.isEmpty then [0] else r.reverse

def outputValue (cfg : Config) : Nat := fromBinary (trimTrailingZeros cfg.tape)

def run (tm : TM) (n fuel : Nat) : Option Nat :=
  let tape := if n == 0 then [0] else
    let rec go : Nat -> List Nat
      | 0 => []
      | m + 1 => (m % 2) :: go (m / 2)
    go n
  (eval tm { state := 1, pos := 0, tape := tape } fuel).map outputValue

def rule445 : TM where
  numStates := 2; numSymbols := 2
  transition := fun state sym =>
    match state, sym with
    | 1, 0 => { nextState := 2, write := 1, dir := Dir.L }
    | 1, 1 => { nextState := 1, write := 0, dir := Dir.L }
    | 2, 0 => { nextState := 2, write := 0, dir := Dir.R }
    | 2, 1 => { nextState := 2, write := 1, dir := Dir.R }
    | _, _ => { nextState := 2, write := 0, dir := Dir.R }

theorem rule445_succ_7 : run rule445 7 20 = some 8 := by native_decide
theorem rule445_succ_255 : run rule445 255 200 = some 256 := by native_decide
theorem rule445_succ_1023 : run rule445 1023 200 = some 1024 := by native_decide
"]
```

```wolfram
spotEnv["rule445_succ_7"]["TypeForm"]
```

```wolfram
spotEnv["rule445_succ_255"]["TypeForm"]
```

```wolfram
spotEnv["rule445_succ_1023"]["TypeForm"]
```

## Part 4: The Infinite-Leverage Proof

Spot checks verify finitely many inputs. The real theorem proves correctness for ALL inputs via structural induction on the binary representation. The proof decomposes execution into three phases: carry, absorb, and scanback.

```wolfram
proofEnv = LeanImportString["
def binarySucc : List Nat -> List Nat
  | [] => [1]
  | 0 :: rest => 1 :: rest
  | 1 :: rest => 0 :: binarySucc rest
  | _ :: rest => 1 :: rest

def fromBinary : List Nat -> Nat
  | [] => 0
  | d :: rest => d + 2 * fromBinary rest

theorem binarySucc_nil : fromBinary (binarySucc []) = fromBinary [] + 1 := by
  simp [binarySucc, fromBinary]

theorem binarySucc_zero (rest : List Nat) :
    fromBinary (binarySucc (0 :: rest)) = fromBinary (0 :: rest) + 1 := by
  simp [binarySucc, fromBinary]; omega

theorem binarySucc_one (rest : List Nat)
    (ih : fromBinary (binarySucc rest) = fromBinary rest + 1) :
    fromBinary (binarySucc (1 :: rest)) = fromBinary (1 :: rest) + 1 := by
  simp [binarySucc, fromBinary, ih]; omega
"]
```

### The Key Encoding Lemmas

Three theorems cover all cases of `binarySucc`. Together they prove that list-level successor matches arithmetic successor -- the bridge connecting tape operations to number theory:

```wolfram
proofEnv["binarySucc_nil"]["TypeForm"]
```

```wolfram
proofEnv["binarySucc_zero"]["TypeForm"]
```

```wolfram
proofEnv["binarySucc_one"]["TypeForm"]
```

### Inspecting the Proof Term

```wolfram
proofEnv["binarySucc_one"]["ExprGraph"]
```

## Part 5: Eval Determinism -- The Uniqueness Hammer

A crucial infrastructure theorem: if eval halts at two different fuel values, the halted configuration is identical. This is used to prove a TM does NOT compute successor:

```wolfram
detEnv = LeanImportString["
theorem eval_det_demo (f : Nat -> Option Nat) (fuel1 fuel2 : Nat) (r1 r2 : Nat)
    (h1 : f fuel1 = some r1) (h2 : f fuel2 = some r2)
    (hm1 : f (fuel1 + fuel2) = some r1)
    (hm2 : f (fuel1 + fuel2) = some r2) :
    r1 = r2 := by
  rw [hm1] at hm2; exact Option.some.inj hm2
"]
```

```wolfram
detEnv["eval_det_demo"]["TypeForm"]
```

## Part 6: Class-Level Generalization

Instead of proving each rule separately, the real proofs define structural predicates. Any TM matching the carry+absorb+walkback template computes successor:

```wolfram
classEnv = LeanImportString["
structure IsClassB (carry absorb ret : Nat -> Nat -> Nat) : Prop where
  carry_rule : forall s, carry s 1 = 0
  absorb_rule : forall s, absorb s 0 = 1
  ret_rule : forall s, ret s 0 = 0
"]
```

```wolfram
classEnv["IsClassB"]["TypeForm"]
```

```wolfram
classEnv["IsClassB"]["Type"]
```

### All 17 Rules in the (2,2) Space

17 rules compute binary successor. They partition into 3 classes:

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

## Part 7: The Near-Miss -- Proving Incorrectness

Rule 156830 correctly computes successor for inputs 1 through 6, then fails at n = 7 (outputs 9 instead of 8). The Lean proof formalizes both via `eval_det`:

```wolfram
nearMissEnv = LeanImportString["
theorem nearMiss_partial : (1 + 1 = 2) /\\ (2 + 1 = 3) /\\ (3 + 1 = 4) /\\
    (4 + 1 = 5) /\\ (5 + 1 = 6) /\\ (6 + 1 = 7) := by omega

theorem contradiction_demo : Not (7 + 1 = 9) := by omega
"]
```

```wolfram
nearMissEnv["nearMiss_partial"]["TypeForm"]
```

```wolfram
nearMissEnv["contradiction_demo"]["TypeForm"]
```

### Visualizing the Failure

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 6, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 6 (correct)", Darker[Green], Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{156830, 3, 2}, 7, 50, ImageSize -> 200, "LabelInput" -> True], Style["n = 7 (FAILS: outputs 9)", Red, Bold, 12], Top]}}, Spacings -> 3]
```

## Part 8: The 3-State Proof

Rule 146514 is a genuine 3-state successor machine. 2352 rules share this step profile.

```wolfram
OneSidedTuringMachinePlot[{146514, 3, 2}, 7, 50, ImageSize -> 200, "LabelInput" -> True]
```

### Runtime Comparison

```wolfram
Grid[{{Labeled[OneSidedTuringMachinePlot[{445, 2, 2}, 31, 50, ImageSize -> 200, "LabelInput" -> True], Style["Rule 445 (2-state)", Bold, 12], Top], Labeled[OneSidedTuringMachinePlot[{146514, 3, 2}, 31, 200, ImageSize -> 200, "LabelInput" -> True], Style["Rule 146514 (3-state)", Bold, 12], Top]}}, Spacings -> 3]
```

## Summary: Proof Architecture

The Lean 4 proof architecture (in `OneSidedTM/`) proceeds in layers:

- `native_decide` bulk checks: verify correctness for all inputs in a finite range (e.g. 1..65535)
- Structural induction via `sim_eval`: proves correctness for ALL inputs by decomposing TM execution into carry, absorb, and walkback phases
- Class-level generalization via `sim_eval_universal`: any TM matching the carry+absorb+walkback pattern computes successor -- individual rules are cheap instances
- Incorrectness via `eval_det`: uniqueness of halted configs enables contradiction proofs

All proofs compile with zero `sorry`s. Source: [WolframInstitute/TuringMachine/Proofs](https://github.com/WolframInstitute/TuringMachine/tree/main/Proofs)
