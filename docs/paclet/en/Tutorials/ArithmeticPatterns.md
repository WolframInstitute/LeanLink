---
Template: TechNote
Name: ArithmeticPatterns
Title: Exact Arithmetic Patterns
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/ArithmeticPatterns
Keywords: [Lean, Mathlib, exact arithmetic, binomial coefficients, greatest common divisor, totient, plot]
RelatedGuides: [LeanLink]
RelatedTutorials: [ComputingWithMathlib, PartialComputations, ValuesAndProofs]
---

Lean computes with exact integers, and [LeanEvaluate]() gives them back as Wolfram Language integers, so a computation with Mathlib's functions can be compared directly with the Wolfram Language's own before a larger pattern is plotted. This tutorial computes binomial coefficients, common divisors and totients. It needs the Mathlib that [InstallMathlib]() installs; every example is guarded so the page still builds where Mathlib is not installed.

## Binomial Coefficients Modulo Two

Record whether Mathlib is installed:

```wl
mathlibReady = MathlibInstallation[]["Status"] === "Ready"
```

<!-- => True (when Mathlib is installed) -->

Import the binomial-coefficient and totient modules:

```wl
env = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Mathlib.Data.Nat.Choose.Basic", "Mathlib.Data.Nat.Totient"}], <||>]
```

<!-- => LeanEnvironment summary box -->

A coefficient computed in Lean:

```wl
LeanEvaluate[env["Nat.choose"], 10, 4]
```

<!-- => 210 -->

The same in the Wolfram Language:

```wl
Binomial[10, 4]
```

<!-- => 210 -->

Rows and columns 0 through 31, modulo two:

```wl
pascal = LeanEvaluate[env, "(List.range 32).map (fun n => (List.range 32).map (fun k => Nat.choose n k % 2))"];
```

The parity pattern, with the row number increasing upward:

```wl
ArrayPlot[Reverse[pascal], DataRange -> {{0, 31}, {0, 31}}, FrameTicks -> Automatic, FrameLabel -> {"Row n", "Column k"}]
```

The whole array agrees with [Binomial]():

```wl
pascal === Table[Mod[Binomial[n, k], 2], {n, 0, 31}, {k, 0, 31}]
```

<!-- => True -->

The triangles repeat within this finite window. The agreement checks the computed array; a statement about every row needs a theorem with its quantifiers, and a proof.

## Common Divisors

The greatest common divisor of each pair of integers from 1 to 32:

```wl
divisors = LeanEvaluate[env, "(List.range 32).map (fun n => (List.range 32).map (fun k => Nat.gcd (n + 1) (k + 1)))"];
```

The array:

```wl
ArrayPlot[divisors, FrameTicks -> Automatic, FrameLabel -> {"First integer", "Second integer"}, PlotLegends -> Automatic]
```

Large values lie on pairs with a large common divisor, and the array is symmetric, as exchanging the arguments keeps their greatest common divisor. Mathlib's theorem says so:

```wl
env["Nat.gcd_comm"]["TypeForm"]
```

<!-- => "∀ (m n : ℕ), m.gcd n = n.gcd m" -->

## Totients

Euler's totient counts the integers from 1 to *n* that are coprime to *n*. Its values for *n* from 1 to 64:

```wl
totients = LeanEvaluate[env, "(List.range 64).map (fun n => Nat.totient (n + 1))"];
```

The counts:

```wl
ListPlot[totients, DataRange -> {1, 64}, AxesLabel -> {"n", "Totient"}]
```

The list agrees with [EulerPhi]():

```wl
totients === EulerPhi[Range[64]]
```

<!-- => True -->

The values stay ordinary exact integers after the transfer, so Wolfram Language plotting and analysis use them as they are, without the theorems or the typeclasses behind them.

Release the environment:

```wl
LeanFreeEnvironment[env]
```
