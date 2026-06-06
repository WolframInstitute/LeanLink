---
Template: Symbol
Name: LeanCompileTyped
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanCompileTyped
Keywords: [Lean, compile, dependent type, TypePi, FunctionCompile, Vector]
SeeAlso: [LeanCompile, LeanToFunction, LeanExprToType]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanCompileTyped]()[*term*]</code> compiles a [LeanTerm]() via [FunctionCompile]() and annotates the result with its dependent type (a `TypePi` signature).

## Details & Options

- For a definition with a **dependent** type - one where a value argument appears in a later argument's type, such as `(n : Nat) -> Vector Int n -> Int` - [LeanCompileTyped]() records the `TypePi` binder on the compiled signature, so currying the size specializes the type.
- For a non-dependent definition it behaves like [LeanCompile](), producing an ordinary [CompiledCodeFunction]().
- The `TypePi` annotation machinery requires a forked Wolfram compiler; see [Possible Issues].

## Basic Examples

On a non-dependent definition it compiles to a runnable function:

```wl
addEnv = LeanImportString["def myAdd (x y : Nat) : Nat := x + y"];
cf = LeanCompileTyped[addEnv["myAdd"]];
cf[3, 4]
```

<!-- => 7 -->

## Possible Issues

The dependent-type path (`Vector`-sized signatures via `TypePi`) needs a forked Wolfram compiler reached through the paclet's `compiler` symlink. Where that fork is absent, only non-dependent definitions compile; [LeanCompile]() auto-selects this path when it detects dependent binders.
