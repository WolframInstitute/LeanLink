---
Template: TechNote
Name: PartialComputations
Title: Observing Partial Computations
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/PartialComputations
Keywords: [Lean, Mathlib, computability, partial recursive functions, fuel, formal model]
RelatedGuides: [LeanLink]
RelatedTutorials: [ComputingWithMathlib, ArithmeticPatterns, ValuesAndProofs]
---

Mathlib's `Nat.Partrec.Code` represents the partial recursive functions on the natural numbers: zero, successor, pairing, composition, primitive recursion and minimization. Its semantics can describe computations that never return a value, and [Mathlib's documentation](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/PartrecCode.html) relates its codes to the class of partial recursive functions. This tutorial runs its bounded evaluator from the Wolfram Language and reads the theorems that relate it to the semantics. It needs the Mathlib that [InstallMathlib]() installs; every example is guarded so the page still builds where Mathlib is not installed.

## A Formal Code Language

Record whether Mathlib is installed:

```wl
mathlibReady = MathlibInstallation[]["Status"] === "Ready"
```

<!-- => True (when Mathlib is installed) -->

Import the code model:

```wl
env = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Mathlib.Computability.PartrecCode"}], <||>]
```

<!-- => LeanEnvironment summary box -->

The theorem that every partial recursive function has a code:

```wl
env["Nat.Partrec.Code.exists_code"]["TypeForm"]
```

It gives a code for every function in the class. It does not say that every such code halts on every input.

## A Bounded Evaluator

`Nat.Partrec.Code.evaln` takes a bound, its fuel, and gives an optional result: a value when the bounded run finishes, and no value when it does not. The fuel belongs to Mathlib's evaluator; it is neither time nor a count of Wolfram Language evaluation steps.

The successor of the successor, run on the inputs 0 through 15 with fuel 20:

```wl
LeanEvaluate[env, "(List.range 16).map (fun n => Nat.Partrec.Code.evaln 20 (.comp .succ .succ) n)"]
```

Which inputs finish, for fuel from 1 to 20:

```wl
finished = LeanEvaluate[env, "(List.range 20).map (fun k => (List.range 16).map (fun n => (Nat.Partrec.Code.evaln (k + 1) (.comp .succ .succ) n).isSome))"];
```

The completion map, fuel increasing to the right. A black cell is a run that gave a value, a white cell one that did not finish:

```wl
ArrayPlot[Reverse[Transpose[Boole[finished]]], DataRange -> {{1, 20}, {0, 15}}, FrameTicks -> Automatic, FrameLabel -> {"Input", "Fuel"}]
```

The number of inputs that finish at each fuel:

```wl
ListStepPlot[Total /@ Boole[finished], DataRange -> {1, 20}, AxesLabel -> {"Fuel", "Completed inputs"}]
```

A white cell at a small fuel is a run that did not finish, not a proof that the computation diverges: larger fuel finishes more inputs.

## Relating Observations to Semantics

The theorem that a value the bounded evaluator gives is a value of the code's semantics:

```wl
env["Nat.Partrec.Code.evaln_sound"]["TypeForm"]
```

And its converse, for a computation that has a value:

```wl
env["Nat.Partrec.Code.evaln_complete"]["TypeForm"]
```

These declarations connect finite observations with the formal semantics. A compiler to this model needs a simulation proof of its own before the model's computability results carry over to another language.

Release the environment:

```wl
LeanFreeEnvironment[env]
```
