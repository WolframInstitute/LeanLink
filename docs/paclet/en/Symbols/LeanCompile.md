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
- Arithmetic (`+`, `-`, `*`, `/`, `%`, `^`), comparisons, `==` and `!=`, the connectives `&&`, `||`, `!` and `xor`, `if` and `bif`, `max` and `min`, decimal literals, and the conversions from `Nat` to `Int` and to `Float` become their Wolfram Language counterparts, and compute as Lean's do on `Nat` and `Int`: `a - b` stops at 0 on `Nat`, dividing by 0 gives 0, and `0 ^ 0` is 1.
- A call to any other function, another definition included, stays in the body as it is, and the definition does not compile.
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
compiled = LeanCompile[env]
```

<!-- => <|"myMul" -> CompiledCodeFunction summary box, "myAdd" -> CompiledCodeFunction summary box|> -->

Run one of them:

```wl
compiled["myMul"][6, 7]
```

<!-- => 42 -->

---

A Lean definition with a Boolean result, compiled from source:

```wl
rangeEnv = LeanImportString["def inRange (n lo hi : Nat) : Bool := lo ≤ n && n < hi || n == 0"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Comparisons and connectives compile like arithmetic:

```wl
inRange = LeanCompile[rangeEnv["inRange"]]
```

<!-- => CompiledCodeFunction summary box: Type {Integer64, Integer64, Integer64} → Boolean -->

```wl
inRange[5, 3, 9]
```

<!-- => True -->
