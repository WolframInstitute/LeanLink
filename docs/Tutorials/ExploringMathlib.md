---
Template: TechNote
Name: ExploringMathlib
Title: Exploring Mathlib with LeanLink
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/ExploringMathlib
Keywords: [Lean, Mathlib, theorem, type, binder, typeclass, instance, proof]
RelatedGuides: [LeanLink]
RelatedTutorials: [LeanLinkIntro, ImportGraph]
---

[Mathlib](https://github.com/leanprover-community/mathlib4) is Lean's community mathematics library. LeanLink imports any built Mathlib module and lets you read theorem statements, dissect their binder structure, and inspect the typeclass machinery behind them - all from the Wolfram Language. Every example below is guarded so the page still builds where Mathlib is absent.

## Prerequisites: Building Mathlib

Install `elan` (the Lean version manager), then create a project with Mathlib as a dependency and build the modules used here:

```
(* Terminal:
   curl https://elan.lean-lang.org/install.sh | sh
   mkdir -p ~/src/mathlib4 && cd ~/src/mathlib4
   lake init MathlibTest math
   lake exe cache get
   lake build Mathlib.Algebra.Group.Basic
   lake build Mathlib.Logic.Basic
*)
```

Point a variable at the checkout and record whether it is built:

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
mathlibReady = DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]]
```

<!-- => True (when Mathlib is built) -->

## Loading a Module

[LeanImport]() reads a module from the project. A `"Filter"` keeps the result small - here, the constants whose names contain `"mul"`:

```wl
algEnv = If[ mathlibReady,
    LeanImport["Mathlib.Algebra.Group.Basic", "ProjectDir" -> mathlibDir, "Filter" -> "mul"],
    <||>];
If[mathlibReady, Length[algEnv], "Mathlib not built"]
```

<!-- => 2272 -->

## Reading a Theorem's Type

A theorem's `"TypeForm"` is the proposition it proves. `mul_comm` states commutativity of multiplication:

```wl
If[mathlibReady, algEnv["mul_comm"]["TypeForm"], "Mathlib not built"]
```

<!-- => "∀ {G : Type u_1} [inst : CommMagma G] (a : G) (b : G), a * b = b * a" -->

And `one_mul` - one is a left identity:

```wl
If[mathlibReady, algEnv["one_mul"]["TypeForm"], "Mathlib not built"]
```

<!-- => "∀ {M : Type u} [inst : MulOneClass M] (a : M), 1 * a = a" -->

## Binder Annotations

Lean has three kinds of argument brackets:

- `(x : T)` - **explicit**: the caller supplies it
- `{x : T}` - **implicit**: Lean infers it from context
- `[inst : T]` - **instance**: Lean resolves it by typeclass search

The `"Parameters"` property unfolds the binder chain and tags each one. As a [Dataset]():

```wl
If[mathlibReady, algEnv["mul_comm"]["Parameters"] // Dataset, "Mathlib not built"]
```

<!-- => Dataset: G (implicit, Type u_1), inst (instance, CommMagma), a and b (explicit) -->

Reading it: to use `mul_comm` you supply two explicit values `a` and `b`; Lean infers the type `G` and finds the `CommMagma` instance automatically.

## Typeclasses

Typeclasses express algebraic structure. Selecting just the instance binders shows what `mul_comm` demands of its type:

```wl
If[ mathlibReady,
    Select[algEnv["mul_comm"]["Parameters"], #Binder == "instance" &] // Dataset,
    "Mathlib not built"]
```

<!-- => Dataset: one row, the CommMagma G instance -->

## Propositional Logic

A different module, the same workflow. Load the logic basics, filtered to the commutativity lemmas:

```wl
logicEnv = If[ mathlibReady,
    LeanImport["Mathlib.Logic.Basic", "ProjectDir" -> mathlibDir, "Filter" -> "comm"],
    <||>];
If[mathlibReady, logicEnv["And.comm"]["TypeForm"], "Mathlib not built"]
```

<!-- => "∀ {a : Prop} {b : Prop}, a ∧ b ⇔ b ∧ a" -->

```wl
If[mathlibReady, logicEnv["Or.comm"]["TypeForm"], "Mathlib not built"]
```

<!-- => "∀ {a : Prop} {b : Prop}, a ∨ b ⇔ b ∨ a" -->

## Expression Graphs

The full type of a theorem, drawn as its expression tree:

```wl
If[mathlibReady, algEnv["mul_comm"]["ExprGraph"], "Mathlib not built"]
```

<!-- => Graph of the mul_comm type tree -->

## Interactive Proofs

Any imported theorem can be opened as a goal with [LeanState]() and stepped with [LeanTactic](). Open `one_mul` and confirm it presents a single goal:

```wl
If[mathlibReady, LeanState[algEnv, "one_mul"]["GoalCount"], "Mathlib not built"]
```

<!-- => 1 -->

The [Getting Started](paclet:Wolfram/LeanLink/tutorial/LeanLinkIntro) tutorial walks a full tactic proof end to end.
