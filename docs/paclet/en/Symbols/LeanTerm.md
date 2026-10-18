---
Template: Symbol
Name: LeanTerm
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanTerm
Keywords: [Lean, term, constant, type, proof, expression, properties]
SeeAlso: [LeanEnvironment, LeanConst, LeanForall, LeanState, LeanCompile]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanTerm]()[*assoc*]</code> represents one Lean constant - its name, kind, type, and body - as returned by indexing a [LeanEnvironment]().

<code>[LeanTerm]()[*expr*, *env*]</code> wraps a hand-built expression tree *expr*, bound to environment *env* so it can be type-checked.

## Details & Options

- A [LeanTerm]() renders as a summary box (icon, name, kind). Query it with properties via <code>*term*["*prop*"]</code>:

| Property | Result |
|---|---|
| `"Type"` / `"Term"` | the type / body as a symbolic expression tree |
| `"TypeForm"` | the type as `#check` prints it, from Lean's own printer; <code>*term*["TypeForm", "Open" -> {*ns*, ...}]</code> prints names under those namespaces unqualified |
| `"TermForm"` | the body pretty-printed as Lean source |
| `"Parameters"` | the binder chain (name, type, binder kind) as rows |
| `"TypeRefs"` / `"TermRefs"` | constants the type / body refers to |
| `"Axioms"` | the axioms the constant depends on, as `#print axioms` reports them; like it, this trusts that every declaration passed the kernel (see Possible Issues) |
| `"KernelCheck"` | the module that declares the constant, replayed through Lean's kernel as `leanchecker` does: a [Success](), or a [Failure]() with the kernel's message |
| `"Module"` | the module that declares the constant |
| `"Source"` | the declaration's source text |
| `"ExprGraph"` / `"CallGraph"` | a [Graph]() of the expression tree / dependencies (a display graph: it omits auxiliary declarations, so use `"Axioms"`, not `"CallGraph"`, to audit axioms) |
| `"Name"` / `"Kind"` | the constant's name / declaration kind |

- The expression tree is built from the CIC heads [LeanConst](), [LeanApp](), [LeanForall](), [LeanLam](), [LeanBVar](), [LeanSort](), [LeanLitNat](), ... which carry box formatting, so a `"Type"` displays in Lean notation rather than as raw heads.

## Basic Examples

A constant from an imported environment:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["id_proof"]
```

<!-- => LeanTerm summary box: Name id_proof, Kind theorem -->

Its type as Lean source, and its proof body:

```wl
env["id_proof"]["TypeForm"]
```

<!-- => "∀ (P : Prop) (a : P), P" -->

```wl
env["id_proof"]["TermForm"]
```

<!-- => "fun x hp => hp" -->

The type as a symbolic tree (rendered in Lean notation by the [LeanForall]() boxes):

```wl
env["id_proof"]["Type"]
```

<!-- => LeanForall["P", LeanSort[LeanLevelZero[]], LeanForall[...], "default"] (renders as ∀ (P : Prop), P → P) -->

## Scope

The binder chain as a [Dataset]():

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
env["modus_ponens"]["Parameters"] // Dataset
```

<!-- => Dataset of 4 rows: P, Q (Prop, explicit), the two hypotheses -->

The expression tree as a graph:

```wl
env["id_proof"]["ExprGraph"]
```

<!-- => Graph (6 vertices) -->

## Properties and Relations

A hand-built expression, bound to an environment, type-checks against it:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
LeanTerm[LeanApp[LeanConst["Nat.succ"], LeanLitNat[42]], env]["TypeForm"]
```

<!-- => "Nat" -->

## Possible Issues

`"Axioms"` reports what `#print axioms` reports, and trusts what it trusts: that every declaration passed Lean's kernel when its module was built. A module can skip that check, with `set_option debug.skipKernelTC true` or by adding a declaration directly with `addDecl`, and a forged proof then shows no axioms. Here a theorem of type `False` is "proved" by `True.intro`:

```wl
forged = LeanImportString["import Lean\nopen Lean Elab Command\nset_option debug.skipKernelTC true in\nrun_cmd liftCoreM <| addDecl <| .thmDecl { name := `Forged.falseProof, levelParams := [], type := mkConst ``False, value := mkConst ``True.intro }"]["Forged.falseProof"];
forged["Axioms"]
```

<!-- => {} -->

`"KernelCheck"` replays the module that declares it through the kernel, as `leanchecker` does, and rejects the forgery:

```wl
forged["KernelCheck"]
```

<!-- => Failure["KernelRejected", ...]: (kernel) declaration type mismatch -->

To verify a proof from an untrusted source, check `"KernelCheck"` as well as `"Axioms"`. From the command line, `lake env leanchecker MyModule` in the built project runs the same replay.
