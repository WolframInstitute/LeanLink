---
Template: Symbol
Name: LeanCompile
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanCompile
Keywords: [Lean, compile, FunctionCompile, native, code, CompiledCodeFunction]
SeeAlso: [LeanToFunction, LeanImportString, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanCompile]()[*term*]</code> compiles a [LeanTerm]() to native code via [FunctionCompile](), returning a [CompiledCodeFunction]().

<code>[LeanCompile]()[*env*]</code> compiles every eligible term in a [LeanEnvironment](), returning an [Association]() from name to compiled function.

## Details & Options

- The Lean definition's argument and result types are mapped to Wolfram compiler types - `Nat` and `Int` to `"MachineInteger"`, `Bool` to `"Boolean"`, `Float` to `"Real64"`, `String` to `"String"` - and the body is lowered through [FunctionCompile]().
- Only computational definitions compile; propositions and theorems are skipped by the environment form.
- A dependent type, such as `Vector Int n`, where the size `n` appears in the type, has no compiler type, so a definition of that type does not compile.

## Basic Examples

A Lean definition, compiled from source:

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Compile a Lean definition to a native function:

```wl
cf = LeanCompile[addEnv["myAdd"]]
```

<!-- => CompiledCodeFunction summary box: Type {Integer64, Integer64} → Integer64 -->

Run it:

```wl
cf[3, 4]
```

<!-- => 7 -->

## Scope

Two Lean definitions, compiled from source:

```wl
env = LeanImportString["def myAdd (x y : Nat) : Nat := x + y
def myMul (x y : Nat) : Nat := x * y"]
```

<!-- => LeanEnvironment summary box: 2 constants -->

Compiling a whole environment returns an [Association]() of the eligible definitions:

```wl
compiled = LeanCompile[env];
Head[compiled]
```

<!-- => Association -->

Run one of them:

```wl
compiled["myMul"][6, 7]
```

<!-- => 42 -->
