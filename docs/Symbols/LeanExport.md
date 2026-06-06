---
Template: Symbol
Name: LeanExport
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanExport
Keywords: [Lean, export, file, source, environment, lean file]
SeeAlso: [LeanExportString, LeanImport, LeanEnvironment, ProofToLean]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanExport]()[*file*, *env*]</code> writes the [LeanEnvironment]() *env* to *file* as Lean 4 source, and returns the file path.

## Details & Options

- *file* is a path ending in `.lean`. The whole environment is serialized in declaration order; the return value is the path written, as [Export]() returns.
- Each constant is emitted as a Lean declaration of its type. A body that cannot be reconstructed as source is written as `sorry`; an environment produced by [ProofToLean]() carries structured tactic proofs that export faithfully.
- For an in-memory string instead of a file, use [LeanExportString]().

## Basic Examples

Export an environment to a temporary `.lean` file:

```wl
env = LeanImportString["theorem myT : Nat.succ 0 = 1 := rfl"];
file = LeanExport[FileNameJoin[{$TemporaryDirectory, "out.lean"}], env]
```

<!-- => "/.../out.lean" -->

The file now exists on disk:

```wl
FileExistsQ[file]
```

<!-- => True -->

Read the first line back:

```wl
First @ StringSplit[Import[file, "Text"], "\n"]
```

<!-- => "theorem myT : (Nat.succ (OfNat.ofNat Nat 0 (instOfNatNat 0))) = (OfNat.ofNat Nat 1 (instOfNatNat 1)) := sorry" -->

## Properties and Relations

[LeanExport]() is [LeanExportString]() followed by a write: <code>[LeanExport]()[*file*, *env*]</code> writes the same text that <code>[LeanExportString]()[*env*]</code> returns.
