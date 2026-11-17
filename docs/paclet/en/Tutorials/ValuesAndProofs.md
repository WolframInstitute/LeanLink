---
Template: TechNote
Name: ValuesAndProofs
Title: Values, Types and Checked Proofs
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/ValuesAndProofs
Keywords: [Lean, Mathlib, types, kernel, proof, axioms, noncomputable, sorry, LeanVerify]
RelatedGuides: [LeanLink]
RelatedTutorials: [ComputingWithMathlib, ArithmeticPatterns, PartialComputations]
---

An evaluation computes a value for the inputs it is given. A theorem states a proposition for all its inputs, with a proof that Lean's kernel checks. The difference matters when a tested example becomes a claim about every input. This tutorial evaluates with [LeanEvaluate](), proves and checks with [LeanImportString]() and [LeanVerify](), and keeps noncomputable definitions as typed terms. It needs the Mathlib that [InstallMathlib]() installs; every example is guarded so the page still builds where Mathlib is not installed.

## A Computation and a Theorem

Record whether Mathlib is installed:

```wl
mathlibReady = MathlibInstallation[]["Status"] === "Ready"
```

<!-- => True (when Mathlib is installed) -->

Import the `ring` tactic:

```wl
env = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Mathlib.Tactic.Ring"}], <||>]
```

<!-- => LeanEnvironment summary box -->

One natural-number instance of an identity, evaluated:

```wl
LeanEvaluate[env, "decide ((4 + 1)^2 = (4 : Nat)^2 + 2*4 + 1)"]
```

<!-- => True -->

The identity for every integer, proved:

```wl
proofs = LeanImportString[env, "theorem squareIdentity (x : Int) : (x + 1)^2 = x^2 + 2*x + 1 := by ring"]
```

<!-- => LeanEnvironment summary box -->

[LeanVerify]() checks the theorem in Lean's kernel and audits the axioms it depends on:

```wl
LeanVerify[proofs["squareIdentity"]]
```

<!-- => Success[...] -->

The theorem's statement:

```wl
proofs["squareIdentity"]["TypeForm"]
```

<!-- => "∀ (x : ℤ), (x + 1) ^ 2 = x ^ 2 + 2 * x + 1" -->

The axioms it depends on:

```wl
proofs["squareIdentity"]["Axioms"]
```

The proof is about the Lean proposition it states. By itself it says nothing about the correctness of a separate Wolfram Language implementation.

`mul_comm` holds in any type with a commutative multiplication; its type states the assumption:

```wl
env["mul_comm"]["TypeForm"]
```

<!-- => "∀ {G : Type u_1} [inst : CommMagma G] (a b : G), a * b = b * a" -->

Release these environments:

```wl
Scan[LeanFreeEnvironment, {proofs, env}]
```

## Typed Terms Without Numerical Values

Mathlib's real numbers support exact reasoning, and many definitions about them are noncomputable: well-typed mathematical objects that Lean's evaluator has no implementation of. Import real square roots:

```wl
reals = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Mathlib.Analysis.Real.Sqrt"}], <||>]
```

<!-- => LeanEnvironment summary box -->

Keep the exact square root of two as a definition:

```wl
roots = LeanImportString[reals, "noncomputable def root : Real := Real.sqrt 2"]
```

<!-- => LeanEnvironment summary box -->

Its type:

```wl
roots["root"]["TypeForm"]
```

<!-- => "ℝ" -->

Its definition:

```wl
roots["root"]["TermForm"]
```

<!-- => "√2" -->

The term stays exact; nothing replaces it with a machine-precision number. Mathlib's theorem about the square of a real square root:

```wl
rootSquare = reals["Real.sq_sqrt"]
```

Its hypothesis, that the number is nonnegative, and its conclusion:

```wl
rootSquare["TypeForm"]
```

<!-- => "∀ {x : ℝ}, 0 ≤ x → √x ^ 2 = x" -->

Lean infers a theorem's implicit arguments and typeclass instances from its type, so Mathlib's theorems can be used in the source given to [LeanImportString]().

Release the square-root environments:

```wl
Scan[LeanFreeEnvironment, {roots, reals}]
```

## Rejected Admissions

Lean's core library is enough for this example:

```wl
core = If[mathlibReady, LeanImport["ProjectDir" -> MathlibInstallation[]["Directory"], "Imports" -> {"Init"}], <||>]
```

<!-- => LeanEnvironment summary box -->

Lean source can contain `sorry`, which admits a proposition without a proof:

```wl
admitted = LeanImportString[core, "theorem admitted : False := by sorry"]
```

<!-- => LeanEnvironment summary box -->

[LeanVerify]() rejects it:

```wl
LeanVerify[admitted["admitted"]]
```

<!-- => Failure["UntrustedProof", ...] -->

A proof that runs out of time is a failed check too, not evidence that the proposition is false; it may need another proof or a larger time limit.

Release these environments:

```wl
Scan[LeanFreeEnvironment, {admitted, core}]
```
