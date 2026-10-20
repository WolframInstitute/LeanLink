---
Template: Symbol
Name: LeanImportString
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanImportString
Keywords: [Lean, import, source, string, compile, environment, theorem]
SeeAlso: [LeanImport, LeanExportString, LeanEnvironment, LeanTerm]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanImportString]()[*src*]</code> compiles a Lean 4 source string and returns a [LeanEnvironment]() of the constants it declares.

<code>[LeanImportString]()[{*src1*, *src2*, ...}]</code> compiles the sources joined with newlines.

## Details & Options

- *src* is ordinary Lean 4 source: any mix of `def`, `theorem`, `inductive`, `structure`, and so on. Each top-level declaration becomes one [LeanTerm]() in the result.
- The string is compiled by the `lean` of LeanLink's pinned toolchain and loaded into the embedded runtime. A type error in *src* returns [$Failed]() with a `LeanImport::err` message carrying Lean's diagnostic, as `lake build` would report it.
- With `"ProjectDir" -> *dir*`, *src* can `import` the modules of the built Lake project in *dir*, of its packages, and of its path dependencies (`path = "../x"` in the lakefile). A theorem proved `by decide` against the project's definitions is then a kernel-checked claim about them.
- Declarations inside a `namespace` are kept under their full names.
- A list of sources is one source, joined with newlines: an `import` line, a few declarations and generated source go in as they are, with no string joining.
- Use [LeanImportString]() for ad-hoc definitions and round-trips; use [LeanImport]() to pull constants from a compiled module such as Mathlib.

## Basic Examples

Compile a single theorem:

```wl
imported = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Read back its type:

```wl
imported["myT"]["TypeForm"]
```

<!-- => "Nat.succ 0 = 1" -->

## Scope

Several declarations at once, as a list of sources:

```wl
env = LeanImportString[{"def double (n : Nat) : Nat := n + n", "theorem myT : Nat.succ 0 = 1 := rfl"}]
```

<!-- => LeanEnvironment summary box: 2 constants -->

Their names:

```wl
Keys[env]
```

<!-- => {"double", "myT"} -->

An inductive type, with everything Lean declares for it:

```wl
defs = LeanImportString["inductive Dir where | L | R deriving Repr"]
```

<!-- => LeanEnvironment summary box: 11 constants -->

Its type:

```wl
defs["Dir"]["TypeForm"]
```

<!-- => "Type" -->

A small project, built with [LeanBuild]():

```wl
dir = CreateDirectory[];
Export[FileNameJoin[{dir, "lakefile.toml"}], {"name = \"demo\"", "[[lean_lib]]", "name = \"Demo\""}, "Lines"];
Export[FileNameJoin[{dir, "lean-toolchain"}], "leanprover/lean4:v4.30.0", "Text"];
Export[FileNameJoin[{dir, "Demo.lean"}], {"namespace Demo", "def triangle (n : Nat) : Nat := n * (n + 1) / 2", "end Demo"}, "Lines"];
LeanBuild[dir, {"Demo"}]
```

<!-- => Success["Built", ...] -->

Import it and check a claim about its definitions with the kernel:

```wl
LeanImportString[{"import Demo", "open Demo", "theorem tri4 : triangle 4 = 10 := by decide"}, "ProjectDir" -> dir]
```

<!-- => LeanEnvironment summary box: 1 constant -->

## Properties and Relations

A Lean theorem, compiled from source:

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"]
```

<!-- => LeanEnvironment summary box: 1 constant -->

Exported back to Lean source:

```wl
src = LeanExportString[env]
```

<!-- => "theorem myT : (@Nat.succ (@OfNat.ofNat Nat (nat_lit 0) (@instOfNatNat (nat_lit 0)))) = (@OfNat.ofNat Nat (nat_lit 1) (@instOfNatNat (nat_lit 1))) := sorry" -->

[LeanImportString]() round-trips with [LeanExportString](): the exported source imports again to the same constant names:

```wl
Keys @ LeanImportString[src]
```

<!-- => {"myT"} -->

## Possible Issues

`wolframscript` reads a `.wls` script as Latin-1, so non-ASCII Lean syntax in a string literal reaches Lean garbled: `¬` arrives as `Â¬`, and Lean reports an unexpected token. The error message shows the token as `¬` again, which hides the cause. Keep such source in a `.lean` file and read it with `Import[file, "Text", CharacterEncoding -> "UTF-8"]`.
