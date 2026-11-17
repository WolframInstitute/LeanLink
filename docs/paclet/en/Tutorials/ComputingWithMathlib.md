---
Template: TechNote
Name: ComputingWithMathlib
Title: Computing with Mathlib
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/ComputingWithMathlib
Keywords: [Lean, Mathlib, install, evaluate, exact arithmetic, binomial coefficient, square root]
RelatedGuides: [LeanLink]
RelatedTutorials: [ArithmeticPatterns, PartialComputations, ValuesAndProofs, ExploringMathlib]
---

[Mathlib](https://github.com/leanprover-community/mathlib4) contains definitions and theorems in algebra, analysis, geometry, number theory, topology and computability. [InstallMathlib]() installs the release built with LeanLink's own Lean toolchain, [LeanImport]() loads its modules as it loads those of any Lean project, and [LeanEvaluate]() computes with its functions, giving exact Wolfram Language values. Every example below is guarded so the page still builds where Mathlib is not installed.

## Installing Mathlib

Install Mathlib once. [InstallMathlib]() also installs elan and the Lean toolchain where they are missing, and downloads several gigabytes of compiled modules with the machine's Git and curl:

```wl
#| eval: false
InstallMathlib[]
```

Record whether the installation is ready:

```wl
mathlibReady = MathlibInstallation[]["Status"] === "Ready"
```

<!-- => True (when Mathlib is installed) -->

## Importing Modules

[LeanImport]() loads modules from the installation's directory. Importing only the modules a computation needs keeps the import fast and small; `"Imports" -> {"Mathlib"}` loads the whole library:

```wl
env = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Mathlib.Data.Nat.Sqrt", "Mathlib.Data.Nat.Choose.Basic"}], <||>]
```

<!-- => LeanEnvironment summary box -->

## Finding and Using a Declaration

The natural-number square-root declarations:

```wl
Select[Keys[env], StringMatchQ[#, "Nat.*sqrt*"]&]
```

The type of the square-root function:

```wl
env["Nat.sqrt"]["TypeForm"]
```

<!-- => "ℕ → ℕ" -->

[LeanEvaluate]() applies it to a Wolfram Language integer. The integer square root of 12345:

```wl
LeanEvaluate[env["Nat.sqrt"], 12345]
```

<!-- => 111 -->

The same in the Wolfram Language:

```wl
Floor[Sqrt[12345]]
```

<!-- => 111 -->

The first evaluation prepares the environment's evaluator; later evaluations reuse it, for applications of imported terms and for Lean expressions alike.

## Computing a Family of Values

One Lean expression can give a whole list. Row ten of Pascal's triangle:

```wl
row = LeanEvaluate[env, "(List.range 11).map (fun k => Nat.choose 10 k)"]
```

<!-- => {1, 10, 45, 120, 210, 252, 210, 120, 45, 10, 1} -->

The values are exact Wolfram Language integers, ready to plot:

```wl
ListPlot[row, DataRange -> {0, 10}, AxesLabel -> {"k", "Binomial coefficient"}]
```

Computing a family in one expression transfers it between the two languages once, rather than once a value.

## Reading a Theorem

A theorem's statement, without evaluating anything:

```wl
env["Nat.add_comm"]["TypeForm"]
```

<!-- => "∀ (n m : ℕ), n + m = m + n" -->

The tutorial *Values, Types and Checked Proofs* adds a theorem to an environment and checks it with [LeanVerify]().

Release the environment and its evaluator:

```wl
LeanFreeEnvironment[env]
```

The installation pins Lean 4.35.0 and Mathlib v4.35.0. [Mathlib's documentation](https://leanprover-community.github.io/mathlib4_docs/) follows Mathlib's development and can describe a newer release.
