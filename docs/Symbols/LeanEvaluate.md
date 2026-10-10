---
Template: Symbol
Name: LeanEvaluate
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanEvaluate
Keywords: [Lean, eval, evaluate, value, JSON, cross-validation, interpreter]
SeeAlso: [LeanImportString, LeanBuild, LeanImport]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanEvaluate]()[*"expr"*]</code> evaluates the Lean expression *expr* with `#eval` and returns its value as a Wolfram Language expression.

## Details & Options

- The value comes back through `Lean.toJson`: `Nat` and `Int` give integers, `Bool` gives [True]() or [False](), `String` gives strings, and `List` and `Array` give lists. A type without a `ToJson` instance fails; wrap the expression in `toString` to get a string instead.
- Options:

| Option | Default | |
|---|---|---|
| `"ProjectDir"` | [None]() | a built Lake project whose modules the expression may use |
| `"Imports"` | `{}` | modules to import |
| `"Open"` | `{}` | namespaces to open |
| `"TimeLimit"` | `600` | seconds before the evaluation is stopped |

- The value is computed by Lean's interpreter, not checked by its kernel. For a kernel-checked claim, state it as a theorem proved `by decide` with [LeanImportString]().
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

Use the definitions of a built project, here one made with [LeanBuild]():

```wl
dir = CreateDirectory[];
Export[FileNameJoin[{dir, "lakefile.toml"}], "name = \"demo\"\n[[lean_lib]]\nname = \"Demo\"\n", "Text"];
Export[FileNameJoin[{dir, "lean-toolchain"}], "leanprover/lean4:v4.30.0", "Text"];
Export[FileNameJoin[{dir, "Demo.lean"}], "namespace Demo\ndef triangle (n : Nat) : Nat := n * (n + 1) / 2\nend Demo\n", "Text"];
LeanBuild[dir, {"Demo"}];
LeanEvaluate["(List.range 8).map triangle", "ProjectDir" -> dir, "Imports" -> {"Demo"}, "Open" -> {"Demo"}]
```

<!-- => {0, 1, 3, 6, 10, 15, 21, 28} -->

## Possible Issues

An expression that does not elaborate gives a [Failure]() with Lean's message:

```wl
LeanEvaluate["undefinedName + 1"]["Tag"]
```

<!-- => "LeanEvaluateFailed" -->
