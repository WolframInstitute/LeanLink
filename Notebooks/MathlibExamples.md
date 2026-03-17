# LeanLink — Exploring Mathlib

## Prerequisites: Installing Mathlib

Install elan (Lean version manager) if not already installed:

```
(* Terminal: curl https://elan.lean-lang.org/install.sh | sh *)
```

Create a Lean project with Mathlib as a dependency and build the modules used in this notebook:

```
(* Terminal:
   mkdir -p ~/src/mathlib4 && cd ~/src/mathlib4
   lake init MathlibTest math
   lake exe cache get
   lake build Mathlib.Tactic.Ring
   lake build Mathlib.Algebra.Group.Basic
   lake build Mathlib.Logic.Basic
   lake build Mathlib.FieldTheory.IsAlgClosed.Basic
*)
```

## Setup

```wolfram
(*PacletDirectoryLoad[NotebookDirectory[] // ParentDirectory];*)
PacletInstall["https://www.wolframcloud.com/obj/nikm/LeanLink.paclet", ForceVersionInstall -> True]
```

```wolfram
Get["LeanLink`"];
mathlibDir = FileNameJoin[{$HomeDirectory, "src", "mathlib4"}];
```

## Part 1: Types and Propositions

In Lean 4 (and Mathlib), every expression has a *type*. Propositions live in `Prop`, data types live in `Type u`. LeanLink lets us inspect these directly.

### Loading an environment

```wolfram
algEnv = LeanImport["Mathlib.Algebra.Group.Basic",
  "ProjectDir" -> mathlibDir,
  "Imports" -> {"Mathlib.Algebra.Group.Basic"}]
```

```wolfram
Length[algEnv]
```

### Reading a theorem's type

`mul_comm` states that multiplication is commutative. Its *type* is the proposition it proves:

```wolfram
algEnv["mul_comm"]["TypeForm"]
```

Compare with `add_zero` — adding zero on the right:

```wolfram
algEnv["add_zero"]["TypeForm"]
```

And `one_mul` — multiplying by one on the left:

```wolfram
algEnv["one_mul"]["TypeForm"]
```

### The expression tree

Behind the pretty-printed string is a symbolic expression tree. `"Type"` returns it:

```wolfram
algEnv["mul_comm"]["Type"]
```

Every Lean expression is built from a small set of constructors: `LeanConst` (named constant), `LeanApp` (function application), `LeanForall` (universal quantifier / function type), `LeanBVar` (bound variable), `LeanLambda`, and `LeanSort`.

## Part 2: Understanding Binder Annotations

Lean uses three kinds of argument brackets:

- `(x : T)` — **explicit**: the caller must provide this
- `{x : T}` — **implicit**: Lean infers this from context
- `[inst : T]` — **instance**: Lean finds this via typeclass search

The new `"Parameters"` property peels apart the forall chain and shows each argument:

```wolfram
algEnv["mul_comm"]["Parameters"] // Dataset
```

The output tells us: to use `mul_comm`, we provide two explicit values `a` and `b`, and Lean auto-resolves the type `G` (implicit) and the `CommMagma` instance.

### Comparing parameter structures

```wolfram
algEnv["add_zero"]["Parameters"] // Dataset
```

`add_zero` needs an `AddZeroClass` instance — Lean will find this automatically for types like `Nat`, `Int`, `Real`.

```wolfram
algEnv["neg_add_cancel"]["Parameters"] // Dataset
```

`neg_add_cancel` requires an `AddGroup` — a monoid with additive inverses.

## Part 3: Typeclasses

Typeclasses are Lean's way of expressing algebraic structure. When you see `[inst : Field k]`, Lean automatically searches for a proof that `k` is a field.

### What typeclasses does `mul_comm` need?

```wolfram
Select[algEnv["mul_comm"]["Parameters"], #Binder == "instance" &] // Dataset
```

### What typeclasses does `sub_eq_add_neg` need?

```wolfram
algEnv["sub_eq_add_neg"]["Parameters"] // Dataset
```

### Building a typeclass hierarchy

Each typeclass extends others. An `AddGroup` extends `AddMonoid` extends `AddZeroClass`. We can see this by inspecting the type of the typeclass itself:

```wolfram
algEnv["AddGroup"]["TypeForm"]
```

## Part 4: Propositional Logic

```wolfram
logicEnv = LeanImport["Mathlib.Logic.Basic",
  "ProjectDir" -> mathlibDir,
  "Imports" -> {"Mathlib.Logic.Basic"}]
```

### The law of excluded middle

Every proposition is either true or false:

```wolfram
logicEnv["Classical.em"]["TypeForm"]
```

```wolfram
logicEnv["Classical.em"]["Parameters"] // Dataset
```

One explicit argument: the proposition `p`. No typeclasses needed — this is pure logic.

### Commutativity of connectives

```wolfram
logicEnv["And.comm"]["TypeForm"]
```

```wolfram
logicEnv["Or.comm"]["TypeForm"]
```

```wolfram
logicEnv["Iff.comm"]["TypeForm"]
```

### Double negation

```wolfram
logicEnv["not_not_not"]["TypeForm"]
```

## Part 5: Interactive Proofs

LeanLink can open any theorem as a proof goal and let you step through it with tactics.

### Opening a proof goal

```wolfram
s0 = LeanState[algEnv, "add_zero"]
```

```wolfram
s0["GoalCount"]
```

```wolfram
s0["Goals"][[1]]["Target"]
```

### Applying tactics

Introduce the universally quantified variables:

```wolfram
s1 = LeanTactic["intro", {"M", "inst", "a"}][s0]
```

```wolfram
s1["Goals"][[1]]["Target"]
```

## Part 6: The Fundamental Theorem of Algebra

The FTA states that $\mathbb{C}$ is algebraically closed: every non-constant polynomial over $\mathbb{C}$ has a root. In Mathlib, this is captured by the `IsAlgClosed` typeclass.

```wolfram
ftaEnv = LeanImport["Mathlib.FieldTheory.IsAlgClosed.Basic",
  "ProjectDir" -> mathlibDir,
  "Imports" -> {"Mathlib.FieldTheory.IsAlgClosed.Basic"},
  "Filter" -> "IsAlgClosed"]
```

```wolfram
Length[ftaEnv]
```

### All IsAlgClosed theorems

```wolfram
Keys[ftaEnv]
```

### The core theorem: existence of roots

`IsAlgClosed.exists_aeval_eq_zero` says: for any polynomial of non-zero degree over an algebraically closed field, there exists a root:

```wolfram
ftaEnv["IsAlgClosed.exists_aeval_eq_zero"]["TypeForm"]
```

### Dissecting the FTA parameters

```wolfram
ftaEnv["IsAlgClosed.exists_aeval_eq_zero"]["Parameters"] // Dataset
```

Reading the parameter table:

- `k : Type u` (explicit) — the algebraically closed field, e.g. $\mathbb{C}$
- `[Field k]` (instance) — `k` must be a field
- `{R : Type}` (implicit) — the coefficient ring
- `[CommSemiring R]` (instance) — `R` must be a commutative semiring
- `[IsAlgClosed k]` (instance) — the key assumption: `k` is algebraically closed
- `[Algebra R k]` (instance) — there's an algebra map $R \to k$
- `[FaithfulSMul R k]` (instance) — the algebra map is injective
- `p : Polynomial R` (explicit) — the polynomial

### The conclusion

After all the parameters, the return type (the thing being proved) is:

$$p.\text{degree} \neq 0 \implies \exists x,\; \text{aeval}(x)(p) = 0$$

"If the polynomial has non-zero degree, then there exists an element $x$ in $k$ such that evaluating $p$ at $x$ gives zero."

### Every polynomial splits

A stronger form: every polynomial factors completely over an algebraically closed field:

```wolfram
ftaEnv["IsAlgClosed.splits_codomain"]["TypeForm"]
```

```wolfram
ftaEnv["IsAlgClosed.splits_codomain"]["Parameters"] // Dataset
```

### Consequences

N-th roots exist in algebraically closed fields:

```wolfram
ftaEnv["IsAlgClosed.exists_pow_nat_eq"]["TypeForm"]
```

Square roots exist:

```wolfram
ftaEnv["IsAlgClosed.exists_eq_mul_self"]["TypeForm"]
```

Algebraically closed fields are necessarily infinite:

```wolfram
ftaEnv["IsAlgClosed.instInfinite"]["TypeForm"]
```

### The construction of the typeclass

The `IsAlgClosed` typeclass is built from a single axiom: all polynomials split:

```wolfram
ftaEnv["IsAlgClosed.mk"]["TypeForm"]
```

```wolfram
ftaEnv["IsAlgClosed.mk"]["Parameters"] // Dataset
```

### Expression tree of the FTA

Visualize the full type of `exists_aeval_eq_zero` as a graph:

```wolfram
ftaEnv["IsAlgClosed.exists_aeval_eq_zero"]["ExprGraph"]
```

### A simple proof: `mul_one`

To see LeanLink's tactic engine in action, let's prove `mul_one` step by step.

Open the proof goal:

```wolfram
s0 = LeanState[algEnv, "mul_one"]
```

The state shows the goal we need to prove. Not yet complete:

```wolfram
s0["Complete"]
```

Introduce the variables:

```wolfram
s1 = LeanTactic["intro M inst a"][s0]
```

```wolfram
s1["Goals"][[1]]["Target"]
```

Close it with the axiom:

```wolfram
s2 = LeanTactic["exact MulOneClass.mul_one a"][s1]
```

```wolfram
s2["Complete"]
```

