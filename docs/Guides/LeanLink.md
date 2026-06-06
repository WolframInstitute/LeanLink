---
Template: Guide
Name: LeanLink
Title: Lean 4 from the Wolfram Language
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/guide/LeanLink
Description: Native bridge to the Lean 4 theorem prover - import Mathlib, inspect proof terms, run tactics, transpile ProofObjects, and compile Lean to native code.
Keywords: [Lean, Lean 4, theorem prover, proof, theorem, tactic, term, Mathlib, dependent types, type theory, LibraryLink, ProofObject, interactive proof]
RelatedTutorials: [LeanLinkIntro, ExploringMathlib, ImportGraph]
Links: ["[Lean 4 (lean-lang.org)](https://lean-lang.org/)", "[Mathlib4 (GitHub)](https://github.com/leanprover-community/mathlib4)"]
---

## Abstract

<code>Wolfram\`LeanLink\`</code> embeds the [Lean 4](https://lean-lang.org/) theorem prover in the Wolfram Language through a native [LibraryLink]() shim. [LeanImport]() and [LeanImportString]() load constants from a compiled module (Mathlib included) or a source string into a [LeanEnvironment]() of [LeanTerm]() values; each term carries its type and proof as symbolic expression trees built from the CIC heads ([LeanConst](), [LeanApp](), [LeanForall](), ...), pretty-prints as Lean source, and draws as a [Graph](). [LeanState]() and [LeanTactic]() run interactive tactic proofs, [ProofToLean]() transpiles a Wolfram [ProofObject]() into checkable Lean, and [LeanCompile]() lowers a Lean definition to a [FunctionCompile]() function.

## Functions

### Importing and exporting

- [LeanImport]() import constants from a compiled Lean module, returning a [LeanEnvironment]()
- [LeanImportString]() compile a Lean 4 source string into a [LeanEnvironment]()
- [LeanExportString]() convert a [LeanEnvironment]() back to Lean 4 source
- [LeanExport]() write a [LeanEnvironment]() to a `.lean` file

### Environments and terms

- [LeanEnvironment]() a collection of named Lean constants; supports [Keys](), [Length](), [Information]()
- [LeanTerm]() one Lean constant, with `"Type"`, `"Term"`, `"TypeForm"`, `"Parameters"`, `"ExprGraph"` properties
- [LeanConstant]() the raw `name / kind / type / term` record returned by the native shim

### Querying a loaded environment

- [LeanExpr]() the type of a constant as a symbolic expression tree
- [LeanValue]() the proof or definition body of a constant
- [LeanConstantInfo]() full constant info as a [LeanConstant]()
- [LeanListConstants]() every constant in a module as an [Association]()
- [LeanLoadEnvironment]() load a Lean environment handle for repeated queries
- [LeanFreeEnvironment]() release a loaded environment handle

### Expression heads (CIC)

- [LeanConst]() a reference to a declared constant at given universe levels
- [LeanApp]() function application
- [LeanForall]() a `∀` / dependent function (arrow) type
- [LeanLam]() a `λ`-abstraction
- [LeanLet]() a `let`-binding
- [LeanBVar]() a bound variable by de Bruijn index
- [LeanFVar]() a free variable (local hypothesis or parameter)
- [LeanMVar]() a metavariable (unresolved placeholder)
- [LeanSort]() a universe (`Prop`, `Type`, ...)
- [LeanLitNat]() a natural-number literal
- [LeanLitStr]() a string literal
- [LeanProj]() a structure-field projection
- [LeanNoValue]() marks a constant with no body (axiom, opaque)
- [LeanTruncated]() marks an expression cut off at the depth limit

### Universe levels

- [LeanLevelZero]() level 0, the universe of `Prop`
- [LeanLevelSucc]() the successor of a level
- [LeanLevelMax]() the maximum of two levels
- [LeanLevelIMax]() the impredicative max (collapses to 0)
- [LeanLevelParam]() a named universe parameter (`u`, `v`)
- [LeanLevelMVar]() a universe metavariable

### Interactive proofs

- [LeanState]() open a theorem as a proof goal; holds `"Goals"`, `"Complete"`, `"GoalCount"`
- [LeanTactic]() a tactic, applied as <code>[LeanTactic]()[*tac*][*state*]</code>
- [LeanGoal]() a single goal, with `"Target"` and `"Context"`

### Transpiling Wolfram proofs

- [ProofToLean]() transpile a Wolfram [ProofObject]() into a checkable [LeanEnvironment]()

### Compiling Lean to native code

- [LeanToFunction]() convert a [LeanTerm]() into a [Function]() with [Typed]() arguments
- [LeanCompile]() compile a [LeanTerm]() (or whole environment) via [FunctionCompile]()
- [LeanCompileTyped]() compile and annotate the result with its dependent type
- [LeanExprToType]() translate a Lean type expression into a compiler type object

### Out-of-process project queries

- [LeanExprGraph]() expression graph for a constant, computed by a Lean subprocess
- [LeanCallGraph]() call / dependency graph for a constant, via subprocess
- [LeanListTheorems]() list a project's theorems via subprocess
- [ImportDOT]() import a DOT digraph file as a styled [Graph]()
