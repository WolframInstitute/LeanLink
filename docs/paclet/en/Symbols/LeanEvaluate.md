---
Template: Symbol
Name: LeanEvaluate
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanEvaluate
Keywords: [Lean, eval, evaluate, value, JSON, cross-validation, interpreter]
SeeAlso: [LeanImportString, LeanBuild, LeanImport, LeanFreeEnvironment, LeanVerify]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanEvaluate]()[*"expr"*]</code> evaluates the Lean expression *expr* with `#eval` and returns its value as a Wolfram Language expression.

<code>[LeanEvaluate]()[*environment*, *"expr"*]</code> evaluates in an imported [LeanEnvironment](), reusing its evaluator between calls.

<code>[LeanEvaluate]()[*term*, *args*]</code> applies an imported [LeanTerm]() to Wolfram Language arguments.

## Details & Options

- The value comes back through `Lean.toJson`: `Nat` and `Int` give integers, `Bool` gives [True]() or [False](), `String` gives strings, `Float` gives machine reals, exactly, with [Infinity]() and [Indeterminate]() for the infinities and NaN, and `List` and `Array` give lists. A type without a `ToJson` instance fails; wrap the expression in `toString` to get a string instead.
- An environment starts its evaluator on the first call, or during [LeanImport]() with `"PrepareEvaluation" -> True`. Later calls reuse the imported modules; computed values are not cached. The string-only form starts a separate process on every call.
- Term arguments can be exact integers, rationals, booleans, strings, lists or other terms from the same environment. Strings are passed as string values. The environment and term forms also return `Rat` values as exact Wolfram rationals.
- For the environment and term forms, select modules and the project with [LeanImport](). `"Source"` declarations apply to the current call only; add imports through [LeanImport]() or [LeanImportString]().
- Give an explicit `"Imports"` list to load several modules together. Automatic project discovery can return a collection of separate environments; its terms can be evaluated individually, but an expression requires one shared environment.
- [LeanFreeEnvironment]() stops the evaluator and releases the environment. `"EvaluatorOnly" -> True` stops the process while keeping the environment available. A timeout or interruption also stops the process; the next call starts a new one.
- Options:

| Option | Default | |
|---|---|---|
| `"ProjectDir"` | [None]() | a built Lake project whose modules the expression may use |
| `"Imports"` | `{}` | modules to import |
| `"Source"` | `""` | Lean declarations the expression uses (definitions, `open`s), placed after the imports |
| `"Open"` | `{}` | namespaces to open |
| `"TimeLimit"` | `600` | seconds before the evaluation is stopped |

- The value is computed by Lean's interpreter. For a checked theorem, use [LeanImportString]() followed by [LeanVerify]().
- An expression that does not elaborate returns a `"LeanEvaluateFailed"` [Failure]() carrying Lean's message; one that runs past `"TimeLimit"` returns a `"TimedOut"` [Failure]().

## Basic Examples

Evaluate Lean expressions:

```wl
LeanEvaluate["(List.range 10).map (· ^ 2)"]
```

<!-- => {0, 1, 4, 9, 16, 25, 36, 49, 64, 81} -->

```wl
LeanEvaluate["decide (2 ^ 10 = 1024)"]
```

<!-- => True -->

## Scope

Compile a function once:

```wl
env = LeanImportString["def square (n : Nat) := n*n"]
```

Apply it to a Wolfram integer:

```wl
LeanEvaluate[env["square"], 12]
```

Evaluate several inputs in one call:

```wl
LeanEvaluate[env, "(List.range 6).map square"]
```

Release the environment when finished:

```wl
LeanFreeEnvironment[env]
```

---

A small project, built with [LeanBuild]():

```wl
dir = CreateDirectory[];
Export[FileNameJoin[{dir, "lakefile.toml"}], {"name = \"demo\"", "[[lean_lib]]", "name = \"Demo\""}, "Lines"];
Export[FileNameJoin[{dir, "lean-toolchain"}], "leanprover/lean4:v4.35.0", "Text"];
Export[FileNameJoin[{dir, "Demo.lean"}], {"namespace Demo", "def triangle (n : Nat) : Nat := n * (n + 1) / 2", "end Demo"}, "Lines"];
LeanBuild[dir, {"Demo"}]
```

<!-- => Success["Built", ...] -->

Evaluate with its definitions:

```wl
LeanEvaluate["(List.range 8).map triangle", "ProjectDir" -> dir, "Imports" -> {"Demo"}, "Open" -> {"Demo"}]
```

<!-- => {0, 1, 3, 6, 10, 15, 21, 28} -->

Give the definitions the expression needs with `"Source"`, here a recursive helper defined by equations:

```wl
LeanEvaluate["(List.range 8).map (fib 1 1)", "Source" -> "def fib (a b : Nat) : Nat -> Nat
  | 0 => a
  | n + 1 => fib b (a + b) n"]
```

<!-- => {1, 1, 2, 3, 5, 8, 13, 21} -->

Large data goes in as definitions too. Split long list literals into chunks of a few hundred elements; one literal of thousands can overflow Lean's code generator.

---

A `Float` comes back as a machine real, every bit of it:

```wl
LeanEvaluate["(0.1 : Float) + 0.2"]
```

<!-- => 0.30000000000000004 -->

## Possible Issues

An expression that does not elaborate gives a [Failure]() with Lean's message:

```wl
LeanEvaluate["undefinedName + 1"]["Tag"]
```

<!-- => "LeanEvaluateFailed" -->
