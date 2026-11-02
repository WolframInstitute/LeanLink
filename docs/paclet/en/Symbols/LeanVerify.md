---
Template: Symbol
Name: LeanVerify
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanVerify
Keywords: [Lean, theorem, kernel, proof, axioms]
SeeAlso: [LeanImportString, LeanTerm, LeanEvaluate]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanVerify]()[*term*]</code> checks a theorem's declaring module in Lean's kernel and audits the theorem's axiom dependencies.

## Details & Options

- *term* must be a theorem in a live imported environment.
- A successful check returns [Success]() containing the kernel result and the actual axiom dependencies.
- Only `propext`, `Quot.sound` and `Classical.choice` are accepted as axiom dependencies. Admitted proofs (`sorry`), additional user axioms and the extra axioms used by `native_decide` are rejected.
- Kernel replay also rejects declarations inserted without kernel type checking. Imported dependencies come from the environment's compiled modules; use trusted builds of those modules.
- `"TimeLimit"` defaults to `600` seconds. Native kernel checks can finish after the requested limit because an active native call may not be interruptible. A timeout returns [Failure](), never a successful verification.
- Evaluation with [LeanEvaluate]() does not verify a proof.

## Basic Examples

Compile a theorem about every natural number:

```wl
env = LeanImportString["theorem addZero (n : Nat) : n + 0 = n := by rfl"]
```

Check its proof:

```wl
LeanVerify[env["addZero"]]
```

Release the environment:

```wl
LeanFreeEnvironment[env]
```

## Possible Issues

An admitted theorem is not verified:

```wl
env = LeanImportString["theorem admitted : False := by sorry"]
```

```wl
LeanVerify[env["admitted"]]["Tag"]
```

```wl
LeanFreeEnvironment[env]
```
