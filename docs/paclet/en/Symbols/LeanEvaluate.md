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

<code>[LeanEvaluate]()[*environment*, *"expr"*]</code> evaluates in an imported [LeanEnvironment](), in the kernel, with the modules LeanLink has already imported.

<code>[LeanEvaluate]()[*term*, *args*]</code> applies an imported [LeanTerm]() to Wolfram Language arguments.

## Details & Options

- The value comes back through `Lean.toJson`: `Nat` and `Int` give integers, `Bool` gives [True]() or [False](), `String` gives strings, `Float` gives machine reals, exactly, with [Infinity]() and [Indeterminate]() for the infinities and NaN, and `List` and `Array` give lists. A type without a `ToJson` instance fails; wrap the expression in `toString` to get a string instead.
- The environment and term forms run in the kernel, on a thread of their own, in the environment [LeanImport]() loaded: nothing is imported again, and a call takes about a millisecond more than Lean's own work. The first call in an environment makes the state later calls start from; [LeanImport]() with `"PrepareEvaluation" -> True` makes it during the import. An environment without Lean's JSON modules, such as `Init`, imports them once for this. Computed values are not cached. The string-only form starts a separate process on every call.
- Term arguments can be exact integers, rationals, booleans, strings, lists or other terms from the same environment. Strings are passed as string values. The environment and term forms also return `Rat` values as exact Wolfram rationals.
- For the environment and term forms, select modules and the project with [LeanImport](). `"Source"` declarations apply to the current call only; add imports through [LeanImport]() or [LeanImportString]().
- Give an explicit `"Imports"` list to load several modules together. Automatic project discovery can return a collection of separate environments; its terms can be evaluated individually, but an expression requires one shared environment.
- In the kernel, an evaluation that passes `"TimeLimit"` or is aborted is asked to stop. Elaboration stops at once, but compiled code that loops or sleeps runs on until it returns: [LeanEvaluate]() returns, and the thread keeps running in the background. While four such evaluations are still running, new ones return a `"Busy"` [Failure](). Code that overflows the stack, calls `IO.Process.exit` or exhausts memory takes the kernel with it. Deep recursion that is not a tail call overflows it sooner than it may seem: `(List.range 10000000).sum` does.
- `"Isolated" -> True` evaluates in a Lean process of the environment's own instead, which imports the environment's modules again when it starts, and keeps them for later isolated calls. A timeout, an abort or a failure kills the process and leaves the kernel untouched; the next call starts a new one. Use it for code that may not terminate.
- [LeanFreeEnvironment]() releases the environment, its evaluation state and its isolated process. `"EvaluatorOnly" -> True` releases only the evaluation state and the process, and keeps the environment.
- Options:

| Option | Default | |
|---|---|---|
| `"ProjectDir"` | [None]() | a built Lake project whose modules the expression may use |
| `"Imports"` | `{}` | modules to import |
| `"Source"` | `""` | Lean declarations the expression uses (definitions, `open`s), placed after the imports |
| `"Open"` | `{}` | namespaces to open |
| `"TimeLimit"` | `600` | seconds before the evaluation is stopped |
| `"Isolated"` | [False]() | whether to evaluate in a Lean process of the environment's own |

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

Code that never returns runs on after the time limit in the kernel. Evaluate it in a process of its own, which the time limit stops:

```wl
env = LeanImport["Init"];
LeanEvaluate[env, "spin 0", "Source" -> "partial def spin (n : Nat) : Nat := spin (n + 1)", "Isolated" -> True, "TimeLimit" -> 2]["Tag"]
```

<!-- => "TimedOut" -->
