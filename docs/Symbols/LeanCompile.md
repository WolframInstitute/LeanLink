---
Template: Symbol
Name: LeanCompile
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanCompile
Keywords: [Lean, compile, FunctionCompile, native, code, CompiledCodeFunction]
SeeAlso: [LeanToFunction, LeanCompileTyped, LeanImportString, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanCompile]()[*term*]</code> compiles a [LeanTerm]() to native code via [FunctionCompile](), returning a [CompiledCodeFunction]().

<code>[LeanCompile]()[*env*]</code> compiles every eligible term in a [LeanEnvironment](), returning an [Association]() from name to compiled function.

## Details & Options

- The Lean definition's argument and result types are mapped to Wolfram compiler types - `Nat` and `Int` to `"MachineInteger"`, `Bool` to `"Boolean"`, `Float` to `"Real64"`, `String` to `"String"` - and the body is lowered through [FunctionCompile]().
- Only computational definitions compile; propositions and theorems are skipped by the environment form.
- The **non-dependent** path runs against the stock Wolfram compiler. The **dependent-type** path (`Vector` sizes carried in a `TypePi` signature) needs a forked compiler; see [LeanCompileTyped]() and [Possible Issues].

## Basic Examples

Compile a Lean definition to a native function and run it:

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"];
cf = LeanCompile[addEnv["myAdd"]]
```

<!-- => CompiledCodeFunction[...] (signature {MachineInteger, MachineInteger} -> MachineInteger) -->

```wl
cf[3, 4]
```

<!-- => 7 -->

## Scope

Compiling a whole environment returns an [Association]() of the eligible definitions:

```wl
env = LeanImportString["def myAdd (x y : Nat) : Nat := x + y
def myMul (x y : Nat) : Nat := x * y"];
compiled = LeanCompile[env];
Head[compiled]
```

<!-- => Association -->

```wl
compiled["myMul"][6, 7]
```

<!-- => 42 -->

## Possible Issues

A definition whose type is **dependent** (for example `Vector Int n`, where the size `n` appears in the type) compiles through [LeanCompileTyped](), which annotates the result with a `TypePi` signature and requires a forked Wolfram compiler. Where that fork is absent, restrict [LeanCompile]() to non-dependent definitions.
