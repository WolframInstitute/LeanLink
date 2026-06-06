---
Template: Symbol
Name: LeanCallGraph
Context: Wolfram`LeanLink`
Paclet: Wolfram/LeanLink
URI: Wolfram/LeanLink/ref/LeanCallGraph
Keywords: [Lean, call graph, dependency, subprocess, visualization, DOT]
SeeAlso: [LeanExprGraph, LeanListTheorems, LeanTerm, ImportDOT]
RelatedGuides: [LeanLink]
---

## Usage

<code>[LeanCallGraph]()[*root*]</code> generates the call / dependency graph of a Lean constant *root* as a [Graph](), computed by a Lean subprocess.

## Details & Options

- The graph's nodes are the constants *root* depends on, with edges from a constant to the constants it uses. It is the dependency view; [LeanExprGraph]() is the expression-tree view.
- Options: `"Files"`, `"Imports"` / `"ProjectDir"`, and `"Depth"` (how many dependency levels to follow).
- Needs `lean` / `lake` on `PATH`; prefer bare `"Files"` over loading a large project for quick graphs.

## Basic Examples

The dependency graph of a proof in the bundled examples file:

```wl
ex = PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"];
LeanCallGraph["or_comm_proof", "Files" -> {ex}]
```

<!-- => Graph: or_comm_proof -> {Or, Or.elim, Or.inl, Or.inr} -->

## Properties and Relations

For a constant already in a [LeanEnvironment](), the in-process `"CallGraph"` property gives the same dependency view without a subprocess:

```wl
env = LeanImport[PacletObject["Wolfram/LeanLink"]["AssetLocation", "Examples"]];
VertexList @ env["or_comm_proof"]["CallGraph"]
```

<!-- => {"or_comm_proof", "Or", "Or.elim", "Or.inl", "Or.inr"} -->
