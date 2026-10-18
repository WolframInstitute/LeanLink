---
Template: TechNote
Name: CheckingMathlib
Title: Checking Mathlib with TypeTheory
Context: Wolfram`LeanLink`
ContextPath: [WolframInstitute`TypeTheory`]
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/tutorial/CheckingMathlib
Keywords: [Lean, Mathlib, TypeTheory, kernel, proof checking, independent checking, Init.Prelude, quotient]
RelatedGuides: [LeanLink]
RelatedTutorials: [ExploringMathlib, LeanLinkIntro, ImportGraph]
---

LeanLink loads a module of [Mathlib](https://github.com/leanprover-community/mathlib4) straight from a built checkout, and [LeanToTypeTheory]() imports its constants, each with every constant it depends on, into an environment of [WolframInstitute/TypeTheory](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory), a proof engine written in the Wolfram Language. TypeTheory's kernel checks every declaration again, independently of Lean's. This tutorial checks a whole module of Mathlib, `Mathlib.Logic.Nonempty`, and shows what TypeTheory does not check yet.

## Prerequisites

The module comes from a built Mathlib checkout, as in the tutorial *Exploring Mathlib with LeanLink*, and the paclet `WolframInstitute/TypeTheory` must be installed:

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
mathlibReady = DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]]
```

<!-- => True (when Mathlib is built) -->

## Loading a Module

`Mathlib.Logic.Nonempty` imports nothing of Mathlib but its initialization, so it sits at the bottom of the library. [LeanImport]() loads it with everything it imports, and the module's own constants are those whose `"Module"` it is:

```wl
module = "Mathlib.Logic.Nonempty";
lean = If[mathlibReady, LeanImport[module, "ProjectDir" -> mathlibDir], <||>];
own = Select[Keys[lean], lean[#]["Module"] === module &];
Length[own]
```

<!-- => 37 -->

They are theorems and definitions about `Nonempty`, such as this one, which says that a statement about every proof that a type is inhabited is a statement about every element:

```wl
lean["Nonempty.forall"]["TypeForm"]
```

<!-- => "∀ {α : Sort u_3} {p : Nonempty α → Prop}, (∀ (h : Nonempty α), p h) ↔ ∀ (a : α), p ⋯" -->

## Checking It in TypeTheory

[LeanToTypeTheory]() imports the 37 constants, and with them every constant they depend on, from Lean's core library and Mathlib's, into one environment, which TypeTheory's kernel checks declaration by declaration:

```wl
checked = LeanToTypeTheory[lean, own];
Length[checked]
```

<!-- => 155 -->

What the environment holds, by kind; each inductive type comes with its constructors and the recursor TypeTheory generates for it, which the import compares with Lean's:

```wl
Information[checked, "Kinds"]
```

<!-- => <|"InductiveType" -> 19, "Constructor" -> 21, "Recursor" -> 19, "Axiom" -> 2, "Definition" -> 55, "Theorem" -> 39|> -->

The module assumes two of Lean's axioms, and nothing else:

```wl
Information[checked, "Axioms"]
```

<!-- => {"propext", "Classical.choice"} -->

## A Theorem in TypeTheory

Lean names stay strings in TypeTheory. The statement of `Nonempty.forall`, as TypeTheory has checked it:

```wl
TypeTheoryCheck[TypeTheoryTerm["Nonempty.forall", checked]]
```

<!-- => ∀_{α∶Sort u_3} ∀_{p∶Nonempty[α] → Prop} Iff[∀_h∶Nonempty[α] p[h], ∀_a∶α p[Nonempty.intro[a]]] -->

A definition shows its value, here the choice of an element from an instance of `Nonempty`:

```wl
checked["Classical.arbitrary"]
```

<!-- => definition Classical.arbitrary : ∀_α∶Sort u_3 ∀_[h∶Nonempty[α]] α := (α∶Sort u_3) [h∶Nonempty[α]] ↦ Classical.choice[h] -->

## Checking It Again

The environment can be checked again from scratch: [TypeTheoryCheck](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory#ref/TypeTheoryCheck) replays every declaration on an empty environment and compares what it gets with what is stored:

```wl
TypeTheoryCheck[checked]
```

<!-- => Success["EnvironmentChecked", ...] -->

## Quotients

Lean's kernel has the computation rule of its quotient types built in: lifting a function to a quotient and applying it to a class gives the function's value. `funext` is proved with it. The import adds the rule as a TypeTheory rewrite rule, under the rules of the calculus of inductive constructions with rewrite rules allowed:

```wl
funext = LeanToTypeTheory[lean, "funext"];
Information[funext, "RewriteRules"]
```

<!-- => {"Quot.lift computes"} -->

```wl
funext["Quot.lift computes"]
```

<!-- => rewrite Quot.lift computes : ∀_α∶Sort u ∀_r∶α → α → Prop ∀_β∶Sort v ∀_f∶α → β ∀_h∶∀_a∶α ∀_b∶α r[a, b] ⇒ Eq[f[a], f[b]] ∀_a∶α Quot.lift[f, h, Quot.mk[r, a]] ⟶ f[a] -->

## What TypeTheory Does Not Check Yet

Lean's first file, `Init.Prelude`, depends on 1,381 constants, and TypeTheory checks 1,182 of them. The 199 it does not check fall into three kinds. The syntax of Lean's own macros and notation uses string literals, which TypeTheory does not have, and 38 constants need one:

```wl
First @ LeanToTypeTheory[lean, "Lean.nullKind"]
```

<!-- => "StringLiteral" -->

Lean's syntax trees are a nested inductive type, holding an array of themselves, and TypeTheory has single inductive families only; 137 constants need them:

```wl
First @ LeanToTypeTheory[lean, "Lean.Syntax"]
```

<!-- => "MutualInductive" -->

And Lean's kernel computes the arithmetic of natural number literals with GMP: `Nat.add`, `Nat.mul`, `Nat.ble` and the others. TypeTheory adds literals as integers but unfolds the other operations, so a proof that a number is below `UInt64.size`, which is 2^64, does not finish; 24 constants, the machine integers and characters, need such arithmetic.

The theorems and definitions of a module about logic need none of the three. Of the sixteen modules at the bottom of Mathlib, thirteen check completely, `Mathlib.Logic.Nonempty`, `Mathlib.Logic.IsEmpty.Defs`, `Mathlib.Logic.Nontrivial.Defs` and `Mathlib.Data.Option.NAry` among them. `Mathlib.Logic.ExistsUnique` and `Mathlib.Logic.Function.Defs` check except for the notation they declare, whose macros are syntax, and two lemmas of `Mathlib.Data.Int.DivMod` reach the empty string through an instance.
