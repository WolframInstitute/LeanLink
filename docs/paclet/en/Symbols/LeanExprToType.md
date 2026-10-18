---
Template: Symbol
Name: LeanExprToType
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanExprToType
Keywords: [Lean, type, TypeFramework, compiler, TypePi, convert]
SeeAlso: [LeanCompileTyped, LeanCompile, LeanForall, LeanConst]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanExprToType]()[*expr*]</code> translates a Lean type expression *expr* into a Wolfram compiler type object.

## Details & Options

- [LeanExprToType]() is the type-side counterpart of [LeanToFunction](): it maps a [LeanForall]() to an arrow or `TypePi` over the mapped leaf types, and a [LeanConst]() to the corresponding type constructor. It underpins the dependent-type path of [LeanCompileTyped]().
- The resulting type object's methods (its `"toString"` form, unification, ...) live in the Wolfram compiler's `TypeFramework`; exercising them requires the forked compiler reached through the paclet's `compiler` symlink.

## Basic Examples

Translate a Lean arrow type `Nat -> Nat` to a compiler type object (shown without evaluating, since inspecting the object needs the forked compiler):

```wl
#| eval: false
LeanExprToType[LeanForall["x", LeanConst["Nat"], LeanConst["Nat"], "default"]]
```

The call returns a `TypePi` / arrow type object over the leaf types `Nat` map to; with the forked compiler loaded, its `"toString"` renders the Wolfram-side type and `TypeUnify` matches it against compiled signatures.
