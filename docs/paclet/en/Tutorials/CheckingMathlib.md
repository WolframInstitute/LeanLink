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

LeanLink loads a module of [Mathlib](https://github.com/leanprover-community/mathlib4) straight from a built checkout, and [LeanToTypeTheory]() imports its constants, each with every constant it depends on, into an environment of [WolframInstitute/TypeTheory](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory), a proof engine written in the Wolfram Language. TypeTheory's kernel checks every declaration again, independently of Lean's. This tutorial checks a whole module of Mathlib, `Mathlib.Basic.Nonempty`, and shows what TypeTheory does not check yet.

## Prerequisites

The module comes from a built Mathlib checkout, as in the tutorial *Exploring Mathlib with LeanLink*, and the paclet `WolframInstitute/TypeTheory` must be installed:

```wl
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
mathlibReady = DirectoryQ[FileNameJoin[{mathlibDir, ".lake", "build"}]]
```

<!-- => True (when Mathlib is built) -->

## Loading a Module

`Mathlib.Basic.Nonempty` imports nothing of Mathlib but its initialization, so it sits at the bottom of the library. [LeanImport]() loads it with everything it imports:

```wl
module = "Mathlib.Basic.Nonempty";
lean = If[mathlibReady, LeanImport[module, "ProjectDir" -> mathlibDir], <||>]
```

<!-- => LeanEnvironment summary box: 106304 constants -->

The module's own constants are those whose `"Module"` it is:

```wl
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
checked = LeanToTypeTheory[lean, own]
```

<!-- => TypeTheoryEnvironment summary box: 155 constants -->

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

Lean's notation, such as `↔` for `Iff`, belongs to Lean's syntax, not to its constants. TypeTheory shows a constant applied to its explicit arguments by giving that expression to [MakeBoxes](), so definitions of [MakeBoxes]() give a Lean name, a string, a notation:

```wl
MakeBoxes["Iff"[a_, b_], form_] := MakeBoxes[Equivalent[a, b], form];
MakeBoxes["Eq"[a_, b_], form_] := MakeBoxes[a == b, form];
MakeBoxes["Or"[a_, b_], form_] := MakeBoxes[Or[a, b], form];
TypeTheoryCheck[TypeTheoryTerm["Nonempty.forall", checked]]
```

<!-- => ∀_{α∶Sort u_3} ∀_{p∶Nonempty[α] → Prop} ((∀_h∶Nonempty[α] p[h]) ⧦ ∀_a∶α p[Nonempty.intro[a]]) -->

## Checking It Again

The environment can be checked again from scratch: [TypeTheoryCheck](https://www.wolframcloud.com/obj/wolframinstitute/TypeTheory#ref/TypeTheoryCheck) replays every declaration on an empty environment and compares what it gets with what is stored:

```wl
TypeTheoryCheck[checked]
```

<!-- => Success["EnvironmentChecked", ...] -->

## Quotients

Lean's kernel has the computation rule of its quotient types built in: lifting a function to a quotient and applying it to a class gives the function's value. `funext` is proved with it. The import adds the rule as a TypeTheory rewrite rule, under the rules of the calculus of inductive constructions with rewrite rules allowed:

```wl
funext = LeanToTypeTheory[lean, "funext"]
```

<!-- => TypeTheoryEnvironment summary box: 13 constants -->

Its rewrite rules:

```wl
Information[funext, "RewriteRules"]
```

<!-- => {"Quot.lift computes"} -->

The rule, as declared:

```wl
funext["Quot.lift computes"]
```

<!-- => rewrite Quot.lift computes : ∀_α∶Sort u ∀_r∶α → α → Prop ∀_β∶Sort v ∀_f∶α → β ∀_h∶∀_a∶α ∀_b∶α r[a, b] ⇒ f[a] == f[b] ∀_a∶α Quot.lift[f, h, Quot.mk[r, a]] ⟶ f[a] -->

## Lean's Prelude

Lean's first file, `Init.Prelude`, depends on 1,381 constants, and TypeTheory checks them all. Three things in it go beyond an inductive family of one type and a sum of literals, and the import follows Lean's kernel in each.

Lean's syntax trees are a nested inductive type: a node holds an array of trees. TypeTheory checks the nesting as Lean's kernel does, and generates a recursor on each container the trees are nested in, the array and the list inside it, which the import compares with Lean's `Lean.Syntax.rec_1` and `Lean.Syntax.rec_2`:

```wl
syntax = LeanToTypeTheory[lean, "Lean.Syntax"]
```

<!-- => TypeTheoryEnvironment summary box: 375 constants -->

The recursors of `Lean.Syntax`, one for the type and one for each container:

```wl
Select[Keys[syntax], MatchQ[InductiveRecursor["Lean.Syntax", ___]]]
```

<!-- => {InductiveRecursor["Lean.Syntax"], InductiveRecursor["Lean.Syntax", 1], InductiveRecursor["Lean.Syntax", 2]} -->

A string literal is the list of its characters, as Lean's kernel reads it, so the names of the syntax kinds import:

```wl
kinds = LeanToTypeTheory[lean, "Lean.nullKind"]
```

<!-- => TypeTheoryEnvironment summary box: 381 constants -->

The name of the null kind, a list of characters:

```wl
kinds["Lean.nullKind"]
```

<!-- => definition Lean.nullKind : Lean.SyntaxNodeKind := Lean.Name.mkStr1[String.ofList[List.cons[Char.ofNat[110], List.cons[Char.ofNat[117], List.cons[Char.ofNat[108], List.cons[Char.ofNat[108], List.nil]]]]]] -->

And Lean's kernel computes `Nat.add`, `Nat.mul`, `Nat.ble` and the other operations on natural number literals with GMP. The import registers each with TypeTheory, which then computes it with integers, so a statement about the size of machine words, 2^32 or 2^64, checks at once:

```wl
words = LeanToTypeTheory[lean, "USize.size_eq"]
```

<!-- => TypeTheoryEnvironment summary box: 113 constants -->

The statement, checked:

```wl
TypeTheoryCheck[TypeTheoryTerm["USize.size_eq", words]]
```

<!-- => USize.size == OfNat.ofNat[4294967296] ∨ USize.size == OfNat.ofNat[18446744073709551616] -->

## Beyond the Prelude

LeanLink's repository has a script, `typetheory_coverage.wls`, that imports every constant of a list of modules, with what it depends on in order, into one TypeTheory environment and reports what checks. The 25 modules at the bottom of Mathlib, from the logic of `Nonempty` and unique existence to options, orderings and folds over lists, check completely, with all 5,291 constants they depend on, in under four minutes. So do 122 modules higher up, each with every constant it depends on, 65,692 distinct constants in all, among them the real and complex numbers, the exponential, logarithm and trigonometric functions, real powers, derivatives, polynomials, matrices and determinants, ideals, separable field extensions, Sylow's theorems, primes and factorizations, cardinals, simple graphs, measurable, metric, uniform and inner product spaces, normed fields, compactness and the p-adic numbers. `Real.sqrt_nonneg` checks too, with the 11,177 constants it depends on through Mathlib's construction of the real numbers, in under seven minutes.

TypeTheory rejects none of these constants. The one constant found so far that it does not check within the five minutes the script allows each constant is a proof by `decide` that a character of `ZMod 8` is 0 off the units, in the cone of quadratic reciprocity. A proof that a tactic writes shares its subterms in Lean, and the import shares them too, translating each distinct subterm once: a proof that `grind` writes in `Mathlib.Data.Int.Init` has 3.6 million nodes written out and under 6,000 distinct ones, and TypeTheory checks it, with the 2,889 constants it depends on, in a minute and a half.
